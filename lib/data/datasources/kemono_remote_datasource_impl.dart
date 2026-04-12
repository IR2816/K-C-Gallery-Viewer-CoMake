import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import '../../domain/entities/api_source.dart';
import '../../utils/logger.dart';
import '../exceptions/api_exceptions.dart';
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../services/api_client.dart';
import '../services/api_header_service.dart';
import '../services/per_domain_http_client.dart';
import '../utils/api_response_utils.dart';
import '../utils/domain_resolver.dart';
import 'kemono_remote_datasource.dart';

class KemonoRemoteDataSourceImpl implements KemonoRemoteDataSource {
  // Pre-compiled regex for JSON extraction – compiled once at class level.
  static final RegExp _jsonPattern = RegExp(r'\[.*?\]|\{.*?\}', dotAll: true);

  // Maximum bytes to scan when searching for embedded JSON in a CSS response.
  static const int _jsonScanLimit = 5120; // 5 KB

  /// Per-domain HTTP client — routes every request to the correct domain
  /// client (Kemono or Coomer) and enforces per-domain request throttling.
  final PerDomainHttpClient _perDomainClient;

  String? get lastSuccessfulDomain => _perDomainClient.lastSuccessfulDomain;

  /// Create with an explicit [PerDomainHttpClient].
  ///
  /// For backward compatibility a legacy [ApiClient] can be passed via
  /// [apiClient]; it wraps the single client in a [PerDomainHttpClient]
  /// that uses the same instance for both domains.
  KemonoRemoteDataSourceImpl({
    PerDomainHttpClient? perDomainClient,
    // ignore: deprecated_member_use_from_same_package
    ApiClient? apiClient,
  }) : _perDomainClient = perDomainClient ??
            PerDomainHttpClient(
              kemonoClient: apiClient ?? ApiClient(),
              coomerClient: apiClient ?? ApiClient(),
            );

  ApiSource _resolveApiSource(String service, ApiSource provided) {
    final resolved = DomainResolver.lockedApiSourceForService(service);
    if (resolved != provided) {
      AppLogger.warning(
        'DomainResolver override: service=$service prefers $resolved (was $provided)',
      );
    }
    return resolved;
  }

  @override
  Future<List<CreatorModel>> getCreators({
    String? service,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final endpoint = '/v1/creators.txt';
    try {
      final jsonList = await _perDomainClient.getJsonList(
        endpoint: endpoint,
        apiSource: apiSource,
        cacheKey: 'creators_${apiSource.name}',
      );

      final creators = ApiResponseUtils.parseList(
        jsonList,
        CreatorModel.fromJson,
      );

      if (service != null && service.isNotEmpty && service != 'all') {
        return creators.where((c) => c.service == service).toList();
      }
      return creators;
    } catch (primaryError, primaryStackTrace) {
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
      } catch (fallbackError, fallbackStackTrace) {
        if (primaryError is ApiException) {
          Error.throwWithStackTrace(primaryError, primaryStackTrace);
        }
        if (fallbackError is ApiException) {
          Error.throwWithStackTrace(fallbackError, fallbackStackTrace);
        }
        throw NetworkRequestException(
          message:
              'Failed to load creators from primary and fallback sources.',
          endpoint: endpoint,
          cause: fallbackError,
          stackTrace: fallbackStackTrace,
        );
      }
    }
  }

  @override
  Future<CreatorModel> getCreator(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final effectiveApiSource = _resolveApiSource(service, apiSource);
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/profile';
    debugPrint(
      'KemonoRemoteDataSource: getCreator endpoint=$endpoint apiSource=$apiSource',
    );
    try {
      final jsonMap = await _perDomainClient.getJsonObject(
        endpoint: endpoint,
        apiSource: effectiveApiSource,
        service: service,
        cacheKey: 'creator_${effectiveApiSource.name}_${service}_$creatorId',
      );

      debugPrint(
        'KemonoRemoteDataSource: getCreator success: ${jsonMap['name']} (${jsonMap['id']})',
      );
      return CreatorModel.fromJson(jsonMap);
    } catch (e, stackTrace) {
      debugPrint('KemonoRemoteDataSource: getCreator error ($endpoint): $e');
      throw mapToApiException(
        e,
        endpoint: endpoint,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<PostModel>> getCreatorPosts(
    String service,
    String creatorId, {
    int offset = 0,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final effectiveApiSource = _resolveApiSource(service, apiSource);
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/posts?o=$offset';
    debugPrint(
      'KemonoRemoteDataSource: getCreatorPosts endpoint=$endpoint apiSource=$apiSource',
    );

    try {
      final jsonList = await _perDomainClient.getJsonList(
        endpoint: endpoint,
        apiSource: effectiveApiSource,
        service: service,
        cacheKey: '${effectiveApiSource.name}_$endpoint',
        normalize: (body, decoded) =>
            ApiResponseUtils.unwrapJsonList(decoded, listKeys: const ['posts']),
      );

      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e, stackTrace) {
      throw mapToApiException(
        e,
        endpoint: endpoint,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<dynamic>> getCreatorLinks(
    String service,
    String creatorId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final effectiveApiSource = _resolveApiSource(service, apiSource);
    final cleanCreatorId = creatorId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/links';
    debugPrint(
      'KemonoRemoteDataSource: getCreatorLinks endpoint=$endpoint apiSource=$apiSource',
    );
    try {
      final jsonList = await _perDomainClient.getJsonList(
        endpoint: endpoint,
        apiSource: effectiveApiSource,
        service: service,
        cacheKey:
            'creator_links_${effectiveApiSource.name}_${service}_$creatorId',
        normalize: (body, decoded) {
          if (decoded is List) return decoded;
          if (decoded is Map<String, dynamic>) return [decoded];
          throw Exception('Unexpected response shape. Expected List or Map.');
        },
      );
      return jsonList;
    } catch (e, stackTrace) {
      throw mapToApiException(
        e,
        endpoint: endpoint,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<PostModel> getPost(
    String service,
    String creatorId,
    String postId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final effectiveApiSource = _resolveApiSource(service, apiSource);
    final cleanCreatorId = creatorId.trim();
    final cleanPostId = postId.trim();
    final endpoint = '/v1/$service/user/$cleanCreatorId/post/$cleanPostId';
    final cacheKey = '${effectiveApiSource.name}_$endpoint';

    try {
      debugPrint(
        'KemonoRemoteDataSource: getPost endpoint=$endpoint apiSource=$apiSource',
      );
      final jsonMap = await _perDomainClient.getJsonObject(
        endpoint: endpoint,
        apiSource: effectiveApiSource,
        service: service,
        cacheKey: cacheKey,
      );

      return PostModel.fromJson(jsonMap);
    } catch (e, stackTrace) {
      throw mapToApiException(
        e,
        endpoint: endpoint,
        stackTrace: stackTrace,
      );
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

    try {
      final jsonList = await _perDomainClient.getJsonList(
        endpoint: endpoint,
        apiSource: apiSource,
        cacheKey: '${apiSource.name}_$endpoint',
        normalize: (body, decoded) =>
            ApiResponseUtils.unwrapJsonList(decoded, listKeys: const ['posts']),
      );

      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e, stackTrace) {
      throw mapToApiException(
        e,
        endpoint: endpoint,
        stackTrace: stackTrace,
      );
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

    try {
      final comments = await _perDomainClient.getJsonList(
        endpoint: endpoint,
        apiSource: DomainResolver.apiSourceForService(service),
        service: service,
        headerVariants: headerVariants,
        normalize: (body, decoded) => _parseCssResponse(body, decoded),
      );
      return comments;
    } catch (e) {
      AppLogger.debug('🔍 DEBUG: All header variants failed with error: $e');
      return [];
    }
  }

  List<dynamic> _parseCssResponse(String responseBody, dynamic decoded) {
    if (kDebugMode) {
      AppLogger.debug(
        '🔍 DEBUG: Parsing CSS response (length: ${responseBody.length})',
      );
      AppLogger.debug('🔍 DEBUG: Full response body: $responseBody');
    }

    if (responseBody.trim().isEmpty) {
      if (kDebugMode) AppLogger.debug('🔍 DEBUG: Empty response body');
      return [];
    }

    // Check if response is HTML error page
    if (responseBody.trim().startsWith('<!') ||
        responseBody.trim().startsWith('<html')) {
      if (kDebugMode) {
        AppLogger.debug('🔍 DEBUG: Response is HTML error page');
        AppLogger.debug(
          '🔍 DEBUG: HTML content: ${responseBody.substring(0, 200)}...',
        );
      }
      return [];
    }

    // Use decoded JSON when available, otherwise attempt decode here
    dynamic parsed = decoded;
    if (parsed == null) {
      try {
        parsed = json.decode(responseBody);
      } catch (e) {
        if (kDebugMode)
          AppLogger.debug('🔍 DEBUG: Direct JSON parsing failed: $e');
      }
    }

    if (parsed != null) {
      if (parsed is List) {
        if (kDebugMode) {
          AppLogger.debug(
            '🔍 DEBUG: Successfully parsed direct JSON list with ${parsed.length} items',
          );
        }
        return parsed;
      } else if (parsed is Map<String, dynamic>) {
        if (kDebugMode) {
          AppLogger.debug(
            '🔍 DEBUG: Parsed JSON object, checking for comments field',
          );
        }
        if (parsed['comments'] is List) {
          if (kDebugMode) {
            AppLogger.debug(
              '🔍 DEBUG: Found comments field with ${parsed['comments'].length} items',
            );
          }
          return parsed['comments'];
        }
        return [parsed];
      }
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
        if (kDebugMode) {
          AppLogger.debug(
            '🔍 DEBUG: Found potential JSON: ${potentialJson.substring(0, potentialJson.length > 100 ? 100 : potentialJson.length)}...',
          );
        }

        try {
          final dynamic decoded = json.decode(potentialJson);
          if (decoded is List) {
            if (kDebugMode) {
              AppLogger.debug(
                '🔍 DEBUG: Successfully parsed JSON list with ${decoded.length} items',
              );
            }
            return decoded;
          } else if (decoded is Map<String, dynamic>) {
            if (kDebugMode)
              AppLogger.debug('🔍 DEBUG: Successfully parsed JSON object');
            return [decoded]; // Wrap single object
          }
        } catch (e) {
          if (kDebugMode)
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

      if (kDebugMode)
        AppLogger.debug('🔍 DEBUG: No valid JSON found in CSS response');
      return [];
    } catch (e) {
      if (kDebugMode) {
        AppLogger.debug('🔍 DEBUG: Error parsing CSS response: $e');
        AppLogger.debug(
          '🔍 DEBUG: CSS response content: ${responseBody.substring(0, 500)}...',
        );
      }
      return [];
    }
  }
}
