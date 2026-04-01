import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/creator_model.dart';
import '../models/post_model.dart';
import 'api_header_service.dart';
import '../utils/api_response_utils.dart';
import '../../domain/entities/api_source.dart';

/// Kemono/Coomer API Helper - Prinsip 1: ID-centric, bukan name-centric
///
/// API ini dioptimalkan untuk service + user_id, BUKAN search engine.
/// Gunakan ID sebagai primary key, name search hanya fitur sekunder.
class KemonoApi {
  // Base URLs dengan fallback
  static const List<String> _kemonoDomains = ['https://kemono.cr/api'];

  static const List<String> _coomerDomains = ['https://coomer.st/api'];

  static String? _lastSuccessfulDomain;

  /// Get headers untuk semua request
  static Map<String, String> get headers => ApiHeaderService.kemonoHeaders;

  /// Simple in-memory cache (endpoint → cached body + expiry)
  static final Map<String, _CachedResponse> _responseCache = {};
  static const Duration _defaultCacheTtl = Duration(minutes: 2);

  /// HTTP request dengan retry + exponential backoff + in-memory cache
  static Future<http.Response> _makeRequest(
    String endpoint, {
    ApiSource apiSource = ApiSource.kemono,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
    bool useCache = true,
    Duration cacheTtl = _defaultCacheTtl,
  }) async {
    final cacheKey = '${apiSource.name}:$endpoint';

    // Return cached response if still valid
    if (useCache) {
      final cached = _responseCache[cacheKey];
      if (cached != null && cached.isValid) {
        debugPrint('KemonoApi: Cache hit for $cacheKey');
        return cached.response;
      }
    }

    final domains = apiSource == ApiSource.kemono
        ? _kemonoDomains
        : _coomerDomains;
    final requestHeaders = ApiHeaderService.getApiHeaders(
      additionalHeaders: additionalHeaders,
    );
    final requestTimeout = timeout ?? const Duration(seconds: 18);

    // Prefer the last-known-good domain first
    final orderedDomains = _lastSuccessfulDomain != null &&
            domains.contains(_lastSuccessfulDomain)
        ? [_lastSuccessfulDomain!, ...domains.where((d) => d != _lastSuccessfulDomain)]
        : domains;

    String? lastError;
    const maxRetries = 2;

    for (final domain in orderedDomains) {
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          // Exponential backoff on retries
          if (attempt > 0) {
            final delay = Duration(milliseconds: 400 * (1 << (attempt - 1)));
            debugPrint('KemonoApi: Retry $attempt after ${delay.inMilliseconds}ms');
            await Future.delayed(delay);
          }

          final url = '$domain$endpoint';
          debugPrint('KemonoApi: Requesting $url (attempt ${attempt + 1})');

          final response = await ApiResponseUtils.withRetry(
            () async => await http
                .get(Uri.parse(url), headers: requestHeaders)
                .timeout(requestTimeout),
            maxRetries: maxRetries,
            delay: (attempt) =>
                Duration(milliseconds: 400 * (1 << attempt)),
          );

          final bodyTrimmed = response.body.trimLeft();
          final looksLikeHtml = ApiResponseUtils.isHtmlResponse(bodyTrimmed);

          if (response.statusCode >= 200 &&
              response.statusCode < 400 &&
              !looksLikeHtml) {
            _lastSuccessfulDomain = domain;
            debugPrint('KemonoApi: Success from $domain');

            // Cache successful response
            if (useCache) {
              _responseCache[cacheKey] =
                  _CachedResponse(response, DateTime.now().add(cacheTtl));
              // Prune cache if too large (keep newest 30 entries)
              if (_responseCache.length > 30) {
                final oldest = _responseCache.entries
                    .reduce((a, b) => a.value.expiresAt.isBefore(b.value.expiresAt) ? a : b);
                _responseCache.remove(oldest.key);
              }
            }

            return response;
          }

          final snippet = bodyTrimmed.length > 200
              ? bodyTrimmed.substring(0, 200)
              : bodyTrimmed;
          lastError =
              'Domain=$domain Status=${response.statusCode} Html=$looksLikeHtml Snippet=${snippet.replaceAll("\n", " ")}';

          // Don't retry on 404 or 403 — move to next domain immediately
          if (response.statusCode == 404 || response.statusCode == 403) {
            break;
          }
        } on TimeoutException catch (e) {
          lastError = 'Domain=$domain Timeout=$e (attempt ${attempt + 1})';
          debugPrint('KemonoApi: Timeout from $domain: $e');
        } catch (e) {
          lastError = 'Domain=$domain Exception=$e';
          debugPrint('KemonoApi: Error from $domain: $e');
          // Only retry on network errors
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Connection')) {
            continue;
          }
          break;
        }
      }
    }

    // Prinsip 5: Error handling yang robust
    throw Exception('All domains failed. Last error: $lastError');
  }

  /// Invalidate cache for a specific endpoint (e.g., after forced refresh)
  static void invalidateCache({String? endpoint, ApiSource? apiSource}) {
    if (endpoint != null && apiSource != null) {
      _responseCache.remove('${apiSource.name}:$endpoint');
    } else {
      _responseCache.clear();
    }
  }

  /// Prinsip 1: Creator by ID (primary method)
  static Future<CreatorModel> getCreatorById(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final endpoint = '/v1/$service/user/$userId/profile';

    try {
      final response = await _makeRequest(endpoint, apiSource: apiSource);

      final dynamic decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        return CreatorModel.fromJson(decoded);
      }

      throw Exception('Invalid response format');
    } catch (e) {
      debugPrint('KemonoApi: getCreatorById failed - $e');
      rethrow;
    }
  }

  /// Prinsip 2: Posts dengan pagination (client bertanggung jawab atas UX)
  static Future<List<PostModel>> getCreatorPosts(
    String service,
    String userId, {
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final endpoint = '/v1/$service/user/$userId/posts?o=$offset&l=$limit';

    try {
      final response = await _makeRequest(endpoint, apiSource: apiSource);

      final dynamic decoded = json.decode(response.body);
      final jsonList = ApiResponseUtils.unwrapJsonList(
        decoded,
        listKeys: const ['posts'],
      );

      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e) {
      debugPrint('KemonoApi: getCreatorPosts failed - $e');
      rethrow;
    }
  }

  /// Recent posts (untuk home page)
  static Future<List<PostModel>> getRecentPosts({
    int offset = 0,
    int limit = 50,
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    final endpoint = '/v1/posts?o=$offset&l=$limit';

    try {
      final response = await _makeRequest(endpoint, apiSource: apiSource);

      final dynamic decoded = json.decode(response.body);
      final jsonList = ApiResponseUtils.unwrapJsonList(
        decoded,
        listKeys: const ['posts'],
      );

      return ApiResponseUtils.parseList(jsonList, PostModel.fromJson);
    } catch (e) {
      debugPrint('KemonoApi: getRecentPosts failed - $e');
      rethrow;
    }
  }

  /// Prinsip 1: Search by ID (prioritas tinggi)
  static Future<CreatorModel?> searchCreatorById(
    String service,
    String userId, {
    ApiSource apiSource = ApiSource.kemono,
  }) async {
    try {
      return await getCreatorById(service, userId, apiSource: apiSource);
    } catch (e) {
      debugPrint('KemonoApi: searchCreatorById not found - $e');
      return null;
    }
  }

  /// Prinsip 1: Search by name (opsional, best-effort)
  static Future<List<CreatorModel>> searchCreatorsByName(
    String query, {
    ApiSource apiSource = ApiSource.kemono,
    String? service,
  }) async {
    // Prinsip 4: Name search adalah opsional dan local-based
    debugPrint('KemonoApi: Name search is secondary feature - $query');

    try {
      final response = await _makeRequest(
        '/v1/creators.txt',
        apiSource: apiSource,
        cacheTtl: const Duration(minutes: 15),
      );

        final dynamic decoded = json.decode(response.body);
        final List<dynamic> jsonList = decoded is List ? decoded : [];
        final creators = ApiResponseUtils.parseList(jsonList, CreatorModel.fromJson);

      final lowerQuery = query.toLowerCase().trim();
      if (lowerQuery.isEmpty) return [];

      // Filter berdasarkan name (secondary search)
      return creators.where((creator) {
        if (service != null && service.isNotEmpty && service != 'all') {
          if (creator.service != service) return false;
        }
        return creator.name.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      debugPrint('KemonoApi: searchCreatorsByName failed - $e');
      return [];
    }
  }

  /// Get last successful domain untuk caching
  static String? get lastSuccessfulDomain => _lastSuccessfulDomain;

  /// Validate headers sebelum request
  static bool validateHeaders() {
    return ApiHeaderService.validateKemonoCoomerHeaders(headers);
  }

  /// Log headers untuk debugging
  static void logHeaders(String context) {
    ApiHeaderService.logHeaders(context, headers);
  }

  // 🚀 NEW: Discord API Methods

  /// Get Discord servers list
  static Future<http.Response> getDiscordServers() async {
    debugPrint('KemonoApi: Getting Discord servers...');
    return await _makeRequest(
      '/v1/discord/server',
      apiSource: ApiSource.kemono,
    );
  }

  /// Get channels for a Discord server
  static Future<http.Response> getDiscordServerChannels(String serverId) async {
    debugPrint('KemonoApi: Getting channels for server $serverId...');
    return await _makeRequest(
      '/v1/discord/server/$serverId',
      apiSource: ApiSource.kemono,
    );
  }

  /// Get posts for a Discord channel
  static Future<http.Response> getDiscordChannelPosts(
    String channelId, {
    int offset = 0,
  }) async {
    debugPrint(
      'KemonoApi: Getting posts for channel $channelId, offset $offset...',
    );
    final endpoint = '/v1/discord/channel/$channelId';
    final params = offset > 0 ? '?o=$offset' : '';
    return await _makeRequest('$endpoint$params', apiSource: ApiSource.kemono);
  }

  /// Lookup Discord channels by server ID
  static Future<http.Response> lookupDiscordChannels(
    String discordServer,
  ) async {
    debugPrint(
      'KemonoApi: Looking up Discord channels for server $discordServer...',
    );
    return await _makeRequest(
      '/v1/discord/channel/lookup/$discordServer',
      apiSource: ApiSource.kemono,
    );
  }

  /// Search Discord servers by name (using mbaharip API)
  static Future<http.Response> searchDiscordServers(String query) async {
    debugPrint('KemonoApi: Searching Discord servers with query: $query');
    // Use mbaharip API for Discord search
    return await _makeRequest(
      '/discord/search?q=${Uri.encodeComponent(query)}',
      apiSource: ApiSource.kemono,
    );
  }
}

/// Internal cache entry for HTTP responses
class _CachedResponse {
  final http.Response response;
  final DateTime expiresAt;

  const _CachedResponse(this.response, this.expiresAt);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}
