import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/domain_config.dart';
import '../../domain/entities/api_source.dart';
import '../../presentation/providers/tracked_http_client.dart';
import '../../utils/logger.dart';
import '../utils/api_response_utils.dart';
import 'api_header_service.dart';

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

class ApiClient {
  final http.Client client;
  final _ApiCache _cache = _ApiCache();
  final Map<String, int> _headerVariantWinnerByDomain = {};
  String? _lastSuccessfulDomain;

  String? get lastSuccessfulDomain => _lastSuccessfulDomain;

  ApiClient({http.Client? client})
      : client = client ?? TrackedHttpClientFactory.getTrackedClient();

  Future<List<dynamic>> getJsonList({
    required String endpoint,
    required ApiSource apiSource,
    Map<String, String>? headers,
    String? cacheKey,
    List<dynamic> Function(String body, dynamic decoded)? normalize,
    List<Map<String, String>>? headerVariants,
  }) async {
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is List) {
        return List<dynamic>.from(cached);
      }
    }

    final response = await _tryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      headers: headers,
      headerVariants: headerVariants,
    );

    final bodyTrimmed = response.body.trimLeft();
    if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
      throw Exception(
        'API returned HTML instead of JSON. Status: ${response.statusCode}',
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(bodyTrimmed);
    } catch (_) {
      decoded = null;
    }

    List<dynamic> result;
    if (normalize != null) {
      result = normalize(bodyTrimmed, decoded);
    } else {
      if (decoded is List) {
        result = decoded;
      } else if (decoded is Map<String, dynamic>) {
        result = ApiResponseUtils.unwrapJsonList(
          decoded,
          listKeys: const ['posts', 'data', 'items'],
        );
      } else {
        throw Exception('Unexpected response shape. Expected JSON list.');
      }
    }

    if (cacheKey != null) {
      _cache.set(cacheKey, result);
    }
    return result;
  }

  Future<Map<String, dynamic>> getJsonObject({
    required String endpoint,
    required ApiSource apiSource,
    Map<String, String>? headers,
    String? cacheKey,
    Map<String, dynamic> Function(String body, dynamic decoded)? normalize,
    List<Map<String, String>>? headerVariants,
  }) async {
    if (cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return Map<String, dynamic>.from(cached);
      }
    }

    final response = await _tryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      headers: headers,
      headerVariants: headerVariants,
    );

    final bodyTrimmed = response.body.trimLeft();
    if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
      throw Exception(
        'API returned HTML instead of JSON. Status: ${response.statusCode}',
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(bodyTrimmed);
    } catch (e) {
      throw Exception('Failed to decode JSON object: $e');
    }

    Map<String, dynamic> result;
    if (normalize != null) {
      result = normalize(bodyTrimmed, decoded);
    } else {
      if (decoded is Map<String, dynamic>) {
        result = decoded;
      } else {
        throw Exception('Unexpected response shape. Expected JSON object.');
      }
    }

    if (cacheKey != null) {
      _cache.set(cacheKey, result);
    }
    return result;
  }

  Future<http.Response> _tryWithFallback({
    required String endpoint,
    required ApiSource apiSource,
    Map<String, String>? headers,
    List<Map<String, String>>? headerVariants,
  }) async {
    final cacheKey = '${apiSource.name}_${endpoint}_${headerVariants?.length ?? 0}';

    final inFlight = _cache.getInFlight(cacheKey);
    if (inFlight != null) {
      AppLogger.debug('Deduping request: $endpoint');
      return await inFlight;
    }

    final requestFuture = _executeTryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      headers: headers,
      headerVariants: headerVariants,
    );
    _cache.setInFlight(cacheKey, requestFuture);
    return await requestFuture;
  }

  Future<http.Response> _executeTryWithFallback({
    required String endpoint,
    required ApiSource apiSource,
    Map<String, String>? headers,
    List<Map<String, String>>? headerVariants,
  }) async {
    final domains = _getDomains(apiSource);
    String? lastError;

    final defaultHeaders = ApiHeaderService.getApiHeaders();

    for (final domain in domains) {
      final variants = _buildHeaderVariants(
        defaultHeaders,
        headers,
        headerVariants,
      );

      final winnerIndex = _headerVariantWinnerByDomain[domain];
      final order = winnerIndex != null
          ? [
              winnerIndex,
              for (int j = 0; j < variants.length; j++)
                if (j != winnerIndex) j,
            ]
          : List.generate(variants.length, (i) => i);

      for (final i in order) {
        final variantHeaders = variants[i];
        final url = '$domain$endpoint';
        AppLogger.network('GET', url, headers: variantHeaders);
        try {
          final response = await client.get(
            Uri.parse(url),
            headers: variantHeaders,
          );

          final bodyTrimmed = response.body.trimLeft();
          final looksLikeHtml = ApiResponseUtils.isHtmlResponse(bodyTrimmed);

          if (response.statusCode >= 200 &&
              response.statusCode < 400 &&
              !looksLikeHtml) {
            _headerVariantWinnerByDomain[domain] = i;
            _lastSuccessfulDomain = domain;
            return response;
          }

          final snippet = bodyTrimmed.length > 200
              ? bodyTrimmed.substring(0, 200)
              : bodyTrimmed;
          lastError =
              'Domain=$domain Status=${response.statusCode} Html=$looksLikeHtml Snippet=${snippet.replaceAll('\n', ' ')}';

          if (response.statusCode == 404) {
            // Try next domain on 404.
            break;
          }
        } catch (e) {
          lastError = 'Domain=$domain Exception=$e';
        }
      }
    }

    throw Exception(
      'All domains failed for endpoint: $endpoint. Last error: $lastError',
    );
  }

  List<Map<String, String>> _buildHeaderVariants(
    Map<String, String> defaultHeaders,
    Map<String, String>? headers,
    List<Map<String, String>>? headerVariants,
  ) {
    if (headerVariants == null || headerVariants.isEmpty) {
      return [
        {...defaultHeaders, ...?headers},
      ];
    }

    return headerVariants
        .map(
          (variant) => {
            ...defaultHeaders,
            ...variant,
            ...?headers,
          },
        )
        .toList();
  }

  List<String> _getDomains(ApiSource apiSource) {
    return apiSource == ApiSource.coomer
        ? DomainConfig.coomerApiDomains
        : DomainConfig.kemonoApiDomains;
  }
}
