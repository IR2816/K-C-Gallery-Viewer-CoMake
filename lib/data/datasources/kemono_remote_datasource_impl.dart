import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../../domain/entities/api_source.dart';
import '../services/api_header_service.dart';
import 'kemono_remote_datasource.dart';
import '../../utils/logger.dart';
import '../../config/domain_config.dart';
import '../../presentation/providers/tracked_http_client.dart';
import '../utils/api_response_utils.dart';

class _ApiCacheEntry {
  final dynamic data;
  final DateTime timestamp;
  DateTime lastAccessed;
  _ApiCacheEntry(this.data, this.timestamp) : lastAccessed = timestamp;
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 5;
}

class _ApiCache {
  static final _ApiCache _instance = _ApiCache._internal();
  factory _ApiCache() => _instance;
  _ApiCache._internal();

  final Map<String, _ApiCacheEntry> _cache = {};
  final Map<String, Future<http.Response>> _inFlightRequests = {};

  dynamic get(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      entry.lastAccessed = DateTime.now();
      return entry.data;
    }
    _cache.remove(key);
    return null;
  }

  void set(String key, dynamic data) {
    if (_cache.length >= 100) {
      // LRU eviction: remove the single least-recently-used entry
      String? lruKey;
      DateTime? oldest;
      for (final e in _cache.entries) {
        if (oldest == null || e.value.lastAccessed.isBefore(oldest)) {
          oldest = e.value.lastAccessed;
          lruKey = e.key;
        }
      }
      if (lruKey != null) _cache.remove(lruKey);
    }
    _cache[key] = _ApiCacheEntry(data, DateTime.now());
  }

  Future<http.Response>? getInFlight(String key) => _inFlightRequests[key];
  void setInFlight(String key, Future<http.Response> request) {
    _inFlightRequests[key] = request;
    request.whenComplete(() => _inFlightRequests.remove(key));
  }
}

class KemonoRemoteDataSourceImpl implements KemonoRemoteDataSource {
  // Pre-compiled regex for JSON extraction – compiled once at class level.
  static final RegExp _jsonPattern = RegExp(r'\[.*?\]|\{.*?\}', dotAll: true);

  // Maximum bytes to scan when searching for embedded JSON in a CSS response.
  static const int _jsonScanLimit = 5120; // 5 KB

  final http.Client client;

  KemonoRemoteDataSourceImpl({http.Client? client})
    : client = client ?? TrackedHttpClientFactory.getTrackedClient();

  String? _lastSuccessfulDomain; // Track last successful domain

  // Per-domain cache of the header variant index that last succeeded.
  final Map<String, int> _successfulHeaderVariantIndex = {};

  // Get last successful domain
  String? get lastSuccessfulDomain => _lastSuccessfulDomain;

  // Get domains dynamically based on API source
  List<String> _getDomains(ApiSource apiSource) {
    if (apiSource == ApiSource.coomer) {
      return DomainConfig.coomerApiDomains;
    } else {
      return DomainConfig.kemonoApiDomains;
    }
  }


  // Try multiple domains with fallback and request deduplication
  Future<http.Response> _tryWithFallback(
    String endpoint,
    Map<String, String>? headers,
    ApiSource apiSource,
  ) async {
    final cacheKey = '${apiSource.name}_$endpoint';
    final cache = _ApiCache();

    // Check for in-flight requests first to deduplicate
    final inFlight = cache.getInFlight(cacheKey);
    if (inFlight != null) {
      AppLogger.debug('Deduping request: $endpoint');
      return await inFlight;
    }

    final requestFuture = _executeTryWithFallback(endpoint, headers, apiSource);
    cache.setInFlight(cacheKey, requestFuture);
    return await requestFuture;
  }

  Future<http.Response> _executeTryWithFallback(
    String endpoint,
    Map<String, String>? headers,
    ApiSource apiSource,
  ) async {
    final domains = _getDomains(apiSource);

    String? lastError;

    // Use ApiHeaderService for consistent headers
    final defaultHeaders = ApiHeaderService.getApiHeaders();

    // Merge with provided headers
    final finalHeaders = {...defaultHeaders, ...?headers};

    AppLogger.network('GET', endpoint, headers: finalHeaders);

    for (final domain in domains) {
      try {
        final url = '$domain$endpoint';
        final response = await client
            .get(Uri.parse(url), headers: finalHeaders);

        final bodyTrimmed = response.body.trimLeft();
        final looksLikeHtml = ApiResponseUtils.isHtmlResponse(bodyTrimmed);

        if (response.statusCode < 200 ||
            response.statusCode >= 400 ||
            looksLikeHtml) {
          final snippet = bodyTrimmed.length > 200
              ? bodyTrimmed.substring(0, 200)
              : bodyTrimmed;
          lastError =
              'Domain=$domain Status=${response.statusCode} Html=$looksLikeHtml Snippet=${snippet.replaceAll("\n", " ")}';

          AppLogger.warning('Request failed', tag: 'Network', error: lastError);
        } else {
          AppLogger.network(
            'SUCCESS',
            url,
            statusCode: response.statusCode,
            response: response.body,
          );
          _lastSuccessfulDomain = domain;
          return response;
        }
        if (response.statusCode == 404) {
          continue;
        }

        // For other errors, still try next domain but log it
        continue;
      } catch (e) {
        lastError = 'Domain=$domain Exception=$e';
        continue;
      }
    }

    // If all domains failed, throw an exception
    throw Exception(
      'All domains failed for endpoint: $endpoint. Last error: $lastError',
    );
  }

  @override
  Future<List<CreatorModel>> getCreators({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final endpoint = '/v1/creators.txt';
    final cacheKey = 'creators_${apiSource.name}';
    final cache = _ApiCache();
    final cachedData = cache.get(cacheKey);
    if (cachedData != null) {
      final list = (cachedData as List).map((e) => CreatorModel.fromJson(e)).toList();
      if (service != null && service.isNotEmpty) {
        return list.where((c) => c.service == service).toList();
      }
      return list;
    }

    final headers = ApiHeaderService.getApiHeaders();

    try {
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      final bodyTrimmed = response.body.trimLeft();
      if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);
      final List<dynamic> jsonList = decoded is List ? decoded : [];

      cache.set(cacheKey, jsonList);

      final creators = ApiResponseUtils.parseList(jsonList, CreatorModel.fromJson);

      if (service != null && service.isNotEmpty && service != 'all') {
        return creators.where((c) => c.service == service).toList();
      }
      return creators;
    } catch (_) {
      // Fallback: derive creator list from recent posts.
      try {
        final posts = await searchPosts(' ', offset: 0, apiSource: apiSource);
        final creatorKeys = <String>{};
        final creators = <CreatorModel>[];

        for (final post in posts) {
          if (service != null &&
              service.isNotEmpty &&
              service != 'all' &&
              post.service != service) {
            continue;
          }
          final key = '${post.service}:${post.user}';
          if (!creatorKeys.contains(key)) {
            creatorKeys.add(key);
            creators.add(
              CreatorModel(
                id: post.user,
                name: 'Creator ${post.user}',
                service: post.service,
                indexed: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            );
          }
        }

        return creators;
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<CreatorModel> getCreator(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/profile';
    debugPrint(
      'KemonoRemoteDataSource: getCreator endpoint=$endpoint apiSource=$apiSource',
    );

    final headers = ApiHeaderService.getApiHeaders();

    try {
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      debugPrint(
        'KemonoRemoteDataSource: getCreator response status=${response.statusCode}',
      );
      debugPrint(
        'KemonoRemoteDataSource: getCreator response body=${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      );

      if (ApiResponseUtils.isHtmlResponse(response.body)) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        debugPrint(
          'KemonoRemoteDataSource: getCreator success: ${decoded['name']} (${decoded['id']})',
        );
        return CreatorModel.fromJson(decoded);
      }
      throw Exception('Unexpected response shape. Expected JSON object.');
    } catch (e) {
      debugPrint('KemonoRemoteDataSource: getCreator error ($endpoint): $e');
      throw Exception('Error fetching creator ($endpoint): $e');
    }
  }

  @override
  Future<List<PostModel>> getCreatorPosts(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/posts?o=$offset';
    debugPrint(
      'KemonoRemoteDataSource: getCreatorPosts endpoint=$endpoint apiSource=$apiSource',
    );

    final cacheKey = '${apiSource.name}_$endpoint';
    final cache = _ApiCache();

    final cachedData = cache.get(cacheKey);
    if (cachedData != null) {
      return (cachedData as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => PostModel.fromJson(e))
          .toList();
    }

    final headers = ApiHeaderService.getApiHeaders();

    try {
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      if (ApiResponseUtils.isHtmlResponse(response.body)) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);
      final List<dynamic> jsonList = ApiResponseUtils.unwrapJsonList(
        decoded,
        listKeys: const ['posts'],
      );

      if (decoded is! List &&
          !(decoded is Map<String, dynamic> && decoded['posts'] is List)) {
        throw Exception(
          'Unexpected response shape. Expected List or {posts: List}.',
        );
      }

      cache.set(cacheKey, jsonList);
      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e) {
      throw Exception('Error fetching posts ($endpoint): $e');
    }
  }

  @override
  Future<List<dynamic>> getCreatorLinks(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/links';
    debugPrint(
      'KemonoRemoteDataSource: getCreatorLinks endpoint=$endpoint apiSource=$apiSource',
    );

    final headers = ApiHeaderService.getApiHeaders();

    try {
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      if (ApiResponseUtils.isHtmlResponse(response.body)) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);

      if (decoded is List) {
        return decoded;
      } else if (decoded is Map<String, dynamic>) {
        return [decoded];
      } else {
        throw Exception('Unexpected response shape. Expected List or Map.');
      }
    } catch (e) {
      throw Exception('Error fetching creator links ($endpoint): $e');
    }
  }

  @override
  Future<PostModel> getPost(
    String service,
    String creatorId,
    String postId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final cleanCreatorId = creatorId.trim();
    final cleanPostId = postId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/post/$cleanPostId';
    final cacheKey = '${apiSource.name}_$endpoint';
    final cache = _ApiCache();

    final cachedData = cache.get(cacheKey);
    if (cachedData != null) {
      return PostModel.fromJson(cachedData);
    }

    final headers = ApiHeaderService.getApiHeaders();

    try {
      debugPrint(
        'KemonoRemoteDataSource: getPost endpoint=$endpoint apiSource=$apiSource',
      );
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      if (response.body.trim().startsWith('<!') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        cache.set(cacheKey, decoded);
        return PostModel.fromJson(decoded);
      }
      throw Exception('Unexpected response shape. Expected JSON object.');
    } catch (e) {
      throw Exception('Error fetching post ($endpoint): $e');
    }
  }

  @override
  Future<List<PostModel>> searchPosts(
    String query, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final trimmed = query.trim();
    final endpoint = trimmed.isEmpty
        ? '/v1/posts?o=$offset&l=$limit'
        : '/v1/posts?q=${Uri.encodeComponent(query)}&o=$offset&l=$limit';

    final cacheKey = '${apiSource.name}_$endpoint';
    final cache = _ApiCache();

    final cachedData = cache.get(cacheKey);
    if (cachedData != null) {
      return (cachedData as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => PostModel.fromJson(e))
          .toList();
    }

    final headers = ApiHeaderService.getApiHeaders();

    try {
      final response = await _tryWithFallback(endpoint, headers, apiSource);

      if (response.body.trim().startsWith('<!') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
          'API returned HTML error page instead of data. Status: ${response.statusCode}',
        );
      }

      final dynamic decoded = json.decode(response.body);
      final List<dynamic> jsonList = ApiResponseUtils.unwrapJsonList(
        decoded,
        listKeys: const ['posts'],
      );

      if (decoded is! List &&
          !(decoded is Map<String, dynamic> && decoded['posts'] is List)) {
        throw Exception(
          'Unexpected response shape. Expected List or {posts: List}.',
        );
      }

      cache.set(cacheKey, jsonList);
      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e) {
      throw Exception('Error searching posts ($endpoint): $e');
    }
  }

  @override
  Future<List<dynamic>> getComments(
    String postId,
    String service,
    String creatorId,
  ) async {
    // Use relative endpoint to avoid double /api issue
    final endpoint = '/v1/$service/user/$creatorId/post/$postId/comments';
    AppLogger.debug('🔍 DEBUG: Using relative endpoint: $endpoint');

    // Header variants ordered by success likelihood (most likely first).
    // Variant 3 (application/json) and Variant 4 (plain API headers) are tried
    // before the CSS-specific variants because modern REST endpoints respond
    // better to standard Accept headers.
    final headerVariants = [
      // Variant 1: JSON Accept header – most likely to succeed on a JSON API
      {...ApiHeaderService.getApiHeaders(), 'Accept': 'application/json'},
      // Variant 2: No special Accept header
      ApiHeaderService.getApiHeaders(),
      // Variant 3: CSS header + standard headers
      {...ApiHeaderService.getApiHeaders(), 'Accept': 'text/css'},
      // Variant 4: CSS header + browser-like User-Agent
      {
        'Accept': 'text/css',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'max-age=0',
      },
    ];

    // Determine the starting variant based on prior success for this domain.
    final domainKey = (_lastSuccessfulDomain ?? 'default');
    final cachedVariant = _successfulHeaderVariantIndex[domainKey];

    // Build iteration order: try the cached winner first, then others.
    final Iterable<int> order = cachedVariant != null
        ? [
            cachedVariant,
            for (int j = 0; j < headerVariants.length; j++)
              if (j != cachedVariant) j,
          ]
        : List.generate(headerVariants.length, (j) => j);

    for (final i in order) {
      final headers = headerVariants[i];
      AppLogger.debug(
        '🔍 DEBUG: Trying header variant ${i + 1}/${headerVariants.length}',
      );
      AppLogger.debug('🔍 DEBUG: Headers: $headers');

      try {
        final response = await _tryWithFallback(
          endpoint,
          headers,
          ApiSource.kemono,
        );
        AppLogger.debug('🔍 DEBUG: Response status: ${response.statusCode}');
        AppLogger.debug('🔍 DEBUG: Response headers: ${response.headers}');
        AppLogger.debug('🔍 DEBUG: Response body: ${response.body}');

        if (response.statusCode == 200) {
          AppLogger.debug('🔍 DEBUG: SUCCESS! Header variant ${i + 1} worked');
          // Cache the winning variant index for this domain.
          _successfulHeaderVariantIndex[domainKey] = i;
          return _parseCssResponse(response.body);
        } else if (response.statusCode == 404) {
          AppLogger.debug('🔍 DEBUG: Header variant ${i + 1} returned 404');
        } else {
          AppLogger.debug(
            '🔍 DEBUG: Header variant ${i + 1} returned ${response.statusCode}',
          );
        }
      } catch (e) {
        AppLogger.debug('🔍 DEBUG: Header variant ${i + 1} failed with error: $e');
      }
    }

    AppLogger.debug('🔍 DEBUG: All header variants failed, returning empty list');
    return [];
  }

  List<dynamic> _parseCssResponse(String responseBody) {
    AppLogger.debug('🔍 DEBUG: Parsing CSS response (length: ${responseBody.length})');
    AppLogger.debug('🔍 DEBUG: Full response body: $responseBody');

    if (responseBody.trim().isEmpty) {
      AppLogger.debug('🔍 DEBUG: Empty response body');
      return [];
    }

    // Check if response is HTML error page
    if (responseBody.trim().startsWith('<!') ||
        responseBody.trim().startsWith('<html')) {
      AppLogger.debug('🔍 DEBUG: Response is HTML error page');
      AppLogger.debug('🔍 DEBUG: HTML content: ${responseBody.substring(0, 200)}...');
      return [];
    }

    // Try to parse as direct JSON first (most likely case)
    try {
      final dynamic decoded = json.decode(responseBody);
      if (decoded is List) {
        AppLogger.debug(
          '🔍 DEBUG: Successfully parsed direct JSON list with ${decoded.length} items',
        );
        return decoded;
      } else if (decoded is Map<String, dynamic>) {
        AppLogger.debug('🔍 DEBUG: Parsed JSON object, checking for comments field');
        if (decoded['comments'] is List) {
          AppLogger.debug(
            '🔍 DEBUG: Found comments field with ${decoded['comments'].length} items',
          );
          return decoded['comments'];
        }
        return [decoded]; // Wrap single object
      }
    } catch (e) {
      AppLogger.debug('🔍 DEBUG: Direct JSON parsing failed: $e');
    }

    // Try to extract JSON from CSS response (fallback)
    try {
      // Scan the first _jsonScanLimit characters using allMatches(str, start)
      // to avoid allocating a substring. Returns early on the first valid JSON.
      final scanEnd = responseBody.length < _jsonScanLimit
          ? responseBody.length
          : _jsonScanLimit;
      final matches = _jsonPattern.allMatches(responseBody, 0);

      for (final match in matches) {
        // Stop scanning once we exceed the initial limit.
        if (match.start >= scanEnd) break;

        final potentialJson = match.group(0)!;
        AppLogger.debug(
          '🔍 DEBUG: Found potential JSON: ${potentialJson.substring(0, potentialJson.length > 100 ? 100 : potentialJson.length)}...',
        );

        try {
          final dynamic decoded = json.decode(potentialJson);
          if (decoded is List) {
            AppLogger.debug(
              '🔍 DEBUG: Successfully parsed JSON list with ${decoded.length} items',
            );
            return decoded;
          } else if (decoded is Map<String, dynamic>) {
            AppLogger.debug('🔍 DEBUG: Successfully parsed JSON object');
            return [decoded]; // Wrap single object
          }
        } catch (e) {
          AppLogger.debug('🔍 DEBUG: Failed to parse potential JSON: $e');
          continue;
        }
      }

      // Fallback: scan the remainder of the body beyond the initial limit.
      if (responseBody.length > _jsonScanLimit) {
        final remainderMatches = _jsonPattern.allMatches(
          responseBody,
          _jsonScanLimit,
        );
        for (final match in remainderMatches) {
          final potentialJson = match.group(0)!;
          try {
            final dynamic decoded = json.decode(potentialJson);
            if (decoded is List) {
              return decoded;
            } else if (decoded is Map<String, dynamic>) {
              return [decoded];
            }
          } catch (_) {
            continue;
          }
        }
      }

      AppLogger.debug('🔍 DEBUG: No valid JSON found in CSS response');
      return [];
    } catch (e) {
      AppLogger.debug('🔍 DEBUG: Error parsing CSS response: $e');
      AppLogger.debug(
        '🔍 DEBUG: CSS response content: ${responseBody.substring(0, 500)}...',
      );
      return [];
    }
  }
}
