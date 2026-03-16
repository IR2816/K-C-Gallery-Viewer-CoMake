import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../models/creator_model.dart';
import '../models/post_model.dart';
import '../../domain/entities/api_source.dart';

/// Kemono/Coomer API Helper - Prinsip 1: ID-centric, bukan name-centric
///
/// API ini dioptimalkan untuk service + user_id, BUKAN search engine.
/// Gunakan ID sebagai primary key, name search hanya fitur sekunder.
class KemonoApi {
  // Prinsip 3.1: Layer API yang rapi dengan helper class
  static const Map<String, String> _headers = {
    'Accept': 'text/css', // WAJIB - tanpa ini API return 403
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Cache-Control': 'max-age=0',
  };

  // Base URLs dengan fallback
  static const List<String> _kemonoDomains = ['https://kemono.cr/api'];

  static const List<String> _coomerDomains = ['https://coomer.st/api'];

  static String? _lastSuccessfulDomain;

  /// Get headers untuk semua request
  static Map<String, String> get headers => Map<String, String>.from(_headers);

  /// HTTP request dengan fallback domain dan error handling
  static Future<http.Response> _makeRequest(
    String endpoint, {
    ApiSource apiSource = ApiSource.kemono,
    Map<String, String>? additionalHeaders,
    Duration? timeout,
  }) async {
    final domains = apiSource == ApiSource.kemono
        ? _kemonoDomains
        : _coomerDomains;
    final requestHeaders = {..._headers, ...?additionalHeaders};
    final requestTimeout = timeout ?? const Duration(seconds: 15);

    String? lastError;

    for (final domain in domains) {
      try {
        final url = '$domain$endpoint';
        debugPrint('KemonoApi: Requesting $url');

        final response = await http
            .get(Uri.parse(url), headers: requestHeaders)
            .timeout(requestTimeout);

        // Validasi response
        final bodyTrimmed = response.body.trimLeft();
        final looksLikeHtml =
            bodyTrimmed.startsWith('<!') ||
            bodyTrimmed.toLowerCase().startsWith('<html');

        if (response.statusCode >= 200 &&
            response.statusCode < 400 &&
            !looksLikeHtml) {
          _lastSuccessfulDomain = domain;
          debugPrint('KemonoApi: Success from $domain');
          return response;
        }

        final snippet = bodyTrimmed.length > 200
            ? bodyTrimmed.substring(0, 200)
            : bodyTrimmed;
        lastError =
            'Domain=$domain Status=${response.statusCode} Html=$looksLikeHtml Snippet=${snippet.replaceAll("\n", " ")}';

        // Jika 404, coba domain lain
        if (response.statusCode == 404) {
          continue;
        }
      } catch (e) {
        lastError = 'Domain=$domain Exception=$e';
        debugPrint('KemonoApi: Error from $domain: $e');
        continue;
      }
    }

    // Prinsip 5: Error handling yang robust
    throw Exception('All domains failed. Last error: $lastError');
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
      final List<dynamic> jsonList = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['posts'] is List)
          ? (decoded['posts'] as List)
          : [];

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => PostModel.fromJson(e))
          .toList();
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
      final List<dynamic> jsonList = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic> && decoded['posts'] is List)
          ? (decoded['posts'] as List)
          : [];

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => PostModel.fromJson(e))
          .toList();
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
      );

      final dynamic decoded = json.decode(response.body);
      final List<dynamic> jsonList = decoded is List ? decoded : [];
      final creators = jsonList
          .whereType<Map<String, dynamic>>()
          .map((e) => CreatorModel.fromJson(e))
          .toList();

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
    return _headers.containsKey('Accept') &&
        _headers.containsKey('User-Agent') &&
        _headers['Accept'] == 'text/css';
  }

  /// Log headers untuk debugging
  static void logHeaders(String context) {
    debugPrint('=== $context Headers ===');
    _headers.forEach((key, value) {
      debugPrint('$key: $value');
    });
    debugPrint('=== End Headers ===');
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
