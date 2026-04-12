import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/domain_config.dart';
import '../../domain/entities/api_source.dart';
import '../../presentation/providers/tracked_http_client.dart';
import '../../utils/api_logger.dart';
import '../../utils/logger.dart';
import '../exceptions/api_exceptions.dart';
import '../utils/api_response_utils.dart';
import '../utils/domain_resolver.dart';
import 'api_header_service.dart';
import 'http_retry_strategy.dart';
import 'network_connectivity_service.dart';

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

  void invalidate(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}

class _CircuitBreakerState {
  int failures = 0;
  DateTime? openedUntil;

  bool get isOpen {
    final until = openedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  void onSuccess() {
    failures = 0;
    openedUntil = null;
  }

  void onFailure({required int threshold, required Duration cooldown}) {
    failures += 1;
    if (failures >= threshold) {
      openedUntil = DateTime.now().add(cooldown);
    }
  }
}

class ApiClient {
  final http.Client client;
  final _ApiCache _cache = _ApiCache();
  final HttpRetryStrategy _retryStrategy;
  final NetworkConnectivityService _connectivityService;
  final Map<String, int> _headerVariantWinnerByDomain = {};
  final Map<String, _CircuitBreakerState> _circuitBreakerByDomain = {};

  static const int _circuitBreakerThreshold = 10;
  static const Duration _circuitBreakerCooldown = Duration(seconds: 10);
  static const int _responseSnippetMaxLength = 200;
  static const int _maxRateLimitWaitSeconds = 3600;
  static const Duration _defaultRateLimitCooldown = Duration(seconds: 15);

  String? _lastSuccessfulDomain;

  String? get lastSuccessfulDomain => _lastSuccessfulDomain;

  ApiClient({
    http.Client? client,
    HttpRetryStrategy? retryStrategy,
    NetworkConnectivityService? connectivityService,
  }) : client = client ?? TrackedHttpClientFactory.getTrackedClient(),
       _retryStrategy = retryStrategy ??
           HttpRetryStrategy(
             policy: const RetryPolicy(
               maxAttempts: 2,
               initialTimeout: Duration(seconds: 10),
               retryTimeout: Duration(seconds: 10),
               baseDelay: Duration(seconds: 1),
               maxDelay: Duration(seconds: 4),
             ),
           ),
       _connectivityService = connectivityService ??
           NetworkConnectivityService.instance {
    _connectivityService.initialize();
  }

  void clearCache() => _cache.clear();

  void invalidateCacheKey(String key) => _cache.invalidate(key);

  Future<List<dynamic>> getJsonList({
    required String endpoint,
    required ApiSource apiSource,
    String? service,
    Map<String, String>? headers,
    String? cacheKey,
    bool forceRefresh = false,
    List<dynamic> Function(String body, dynamic decoded)? normalize,
    List<Map<String, String>>? headerVariants,
  }) async {
    if (!forceRefresh && cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is List) {
        return List<dynamic>.from(cached);
      }
    }

    if (forceRefresh && cacheKey != null) {
      _cache.invalidate(cacheKey);
    }

    final response = await _tryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      service: service,
      headers: headers,
      headerVariants: headerVariants,
    );

    final bodyTrimmed = response.body.trimLeft();
    if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
      throw ApiParsingException(
        message: 'API returned HTML instead of JSON.',
        endpoint: endpoint,
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(bodyTrimmed);
    } catch (e, stackTrace) {
      throw ApiParsingException(
        message: 'Failed to decode JSON list.',
        endpoint: endpoint,
        cause: e,
        stackTrace: stackTrace,
      );
    }

    final result = normalize != null
        ? normalize(bodyTrimmed, decoded)
        : decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? ApiResponseUtils.unwrapJsonList(
            decoded,
            listKeys: const ['posts', 'data', 'items'],
          )
        : throw ApiParsingException(
            message: 'Unexpected response shape. Expected JSON list.',
            endpoint: endpoint,
          );

    if (cacheKey != null) {
      _cache.set(cacheKey, result);
    }
    return result;
  }

  Future<Map<String, dynamic>> getJsonObject({
    required String endpoint,
    required ApiSource apiSource,
    String? service,
    Map<String, String>? headers,
    String? cacheKey,
    bool forceRefresh = false,
    Map<String, dynamic> Function(String body, dynamic decoded)? normalize,
    List<Map<String, String>>? headerVariants,
  }) async {
    if (!forceRefresh && cacheKey != null) {
      final cached = _cache.get(cacheKey);
      if (cached != null && cached is Map<String, dynamic>) {
        return Map<String, dynamic>.from(cached);
      }
    }

    if (forceRefresh && cacheKey != null) {
      _cache.invalidate(cacheKey);
    }

    final response = await _tryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      service: service,
      headers: headers,
      headerVariants: headerVariants,
    );

    final bodyTrimmed = response.body.trimLeft();
    if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
      throw ApiParsingException(
        message: 'API returned HTML instead of JSON.',
        endpoint: endpoint,
      );
    }

    dynamic decoded;
    try {
      decoded = json.decode(bodyTrimmed);
    } catch (e, stackTrace) {
      throw ApiParsingException(
        message: 'Failed to decode JSON object.',
        endpoint: endpoint,
        cause: e,
        stackTrace: stackTrace,
      );
    }

    final result = normalize != null
        ? normalize(bodyTrimmed, decoded)
        : decoded is Map<String, dynamic>
        ? decoded
        : throw ApiParsingException(
            message: 'Unexpected response shape. Expected JSON object.',
            endpoint: endpoint,
          );

    if (cacheKey != null) {
      _cache.set(cacheKey, result);
    }
    return result;
  }

  Future<http.Response> _tryWithFallback({
    required String endpoint,
    required ApiSource apiSource,
    String? service,
    Map<String, String>? headers,
    List<Map<String, String>>? headerVariants,
  }) async {
    return _executeTryWithFallback(
      endpoint: endpoint,
      apiSource: apiSource,
      service: service,
      headers: headers,
      headerVariants: headerVariants,
    );
  }

  Future<http.Response> _executeTryWithFallback({
    required String endpoint,
    required ApiSource apiSource,
    String? service,
    Map<String, String>? headers,
    List<Map<String, String>>? headerVariants,
  }) async {
    final requestId = ApiLogger.nextRequestId();
    final hasNetwork = await _connectivityService.hasNetworkConnection();
    if (!hasNetwork) {
      throw NetworkUnavailableException(endpoint: endpoint, requestId: requestId);
    }

    final domains = _getDomainsWithService(apiSource, service: service);
    String? lastError;
    DateTime? earliestRetryAfter;

    final defaultHeaders = ApiHeaderService.getApiHeaders();

    for (final domain in domains) {
      final breaker = _circuitBreakerByDomain.putIfAbsent(
        domain,
        () => _CircuitBreakerState(),
      );

      if (breaker.isOpen) {
        final retryAfter = breaker.openedUntil;
        if (retryAfter != null &&
            (earliestRetryAfter == null || retryAfter.isBefore(earliestRetryAfter))) {
          earliestRetryAfter = retryAfter;
        }
        continue;
      }

      final variants = _buildHeaderVariants(
        defaultHeaders,
        headers,
        headerVariants,
      );

      final winnerIndex = _headerVariantWinnerByDomain[domain];
      final order = winnerIndex != null
          ? [
              winnerIndex,
              for (var j = 0; j < variants.length; j++)
                if (j != winnerIndex) j,
            ]
          : List.generate(variants.length, (i) => i);

      for (final i in order) {
        final variantHeaders = variants[i];
        final url = '$domain$endpoint';

        try {
          final response = await _retryStrategy.execute<http.Response>(
            operation: (attemptIndex, timeout) async {
              final startedAt = DateTime.now();
              ApiLogger.request(
                requestId: requestId,
                method: 'GET',
                url: url,
                headers: variantHeaders,
                attempt: attemptIndex + 1,
              );

              final response = await client
                  .get(Uri.parse(url), headers: variantHeaders)
                  .timeout(
                    timeout,
                    onTimeout: () => throw RequestTimeoutException(
                      message: 'Request timed out after ${timeout.inSeconds}s.',
                      endpoint: endpoint,
                      requestId: requestId,
                    ),
                  );

              final duration = DateTime.now().difference(startedAt);
              final bodyTrimmed = response.body.trimLeft();
              final snippet = bodyTrimmed.length > _responseSnippetMaxLength
                  ? bodyTrimmed.substring(0, _responseSnippetMaxLength)
                  : bodyTrimmed;

              ApiLogger.response(
                requestId: requestId,
                method: 'GET',
                url: url,
                statusCode: response.statusCode,
                duration: duration,
                bodySnippet: snippet.replaceAll('\n', ' '),
              );

              if (response.statusCode >= 500) {
                throw HttpStatusException(
                  message: 'Server error ${response.statusCode}',
                  statusCode: response.statusCode,
                  endpoint: endpoint,
                  requestId: requestId,
                );
              }

              if (response.statusCode == 429) {
                final now = DateTime.now();
                final parsedRetryAfter = _resolveRetryAfter(response);
                final waitSeconds = parsedRetryAfter
                    .difference(now)
                    .inSeconds
                    .clamp(1, _maxRateLimitWaitSeconds);
                final retryAfter = now.add(Duration(seconds: waitSeconds));
                throw RateLimitException(
                  message: 'Rate limited (429). Retry after ${waitSeconds}s.',
                  retryAfter: retryAfter,
                  endpoint: endpoint,
                  requestId: requestId,
                );
              }

              if (response.statusCode >= 400) {
                throw HttpStatusException(
                  message: 'Client error ${response.statusCode}',
                  statusCode: response.statusCode,
                  endpoint: endpoint,
                  requestId: requestId,
                );
              }

              if (ApiResponseUtils.isHtmlResponse(bodyTrimmed)) {
                throw ApiParsingException(
                  message: 'API returned HTML instead of JSON.',
                  endpoint: endpoint,
                  requestId: requestId,
                );
              }

              return response;
            },
            isRetryable: (error) {
              if (error is ApiException) return error.isRetryable;
              final mapped = mapToApiException(
                error,
                endpoint: endpoint,
                requestId: requestId,
              );
              return mapped.isRetryable;
            },
            onRetry: (attemptIndex, error) {
              AppLogger.warning(
                'Retrying request $requestId (attempt ${attemptIndex + 2})',
                tag: 'ApiClient',
                error: error,
              );
            },
          );

          _headerVariantWinnerByDomain[domain] = i;
          _lastSuccessfulDomain = domain;
          breaker.onSuccess();
          return response;
        } catch (error, stackTrace) {
          final mapped = mapToApiException(
            error,
            endpoint: endpoint,
            requestId: requestId,
            stackTrace: stackTrace,
          );

          ApiLogger.failure(
            requestId: requestId,
            method: 'GET',
            url: url,
            error: mapped,
            statusCode: mapped.statusCode,
          );

          lastError = mapped.toString();
          breaker.onFailure(
            threshold: _circuitBreakerThreshold,
            cooldown: _circuitBreakerCooldown,
          );

          if (mapped is HttpStatusException && mapped.statusCode == 404) {
            break;
          }
        }
      }
    }

    if (earliestRetryAfter != null) {
      throw CircuitBreakerOpenException(
        retryAfter: earliestRetryAfter,
        endpoint: endpoint,
        requestId: requestId,
      );
    }

    throw NetworkRequestException(
      message: 'All domains failed for endpoint: $endpoint. Last error: $lastError',
      endpoint: endpoint,
      requestId: requestId,
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
        .map((variant) => {...defaultHeaders, ...variant, ...?headers})
        .toList();
  }

  List<String> _getDomainsWithService(ApiSource apiSource, {String? service}) {
    final domains = DomainResolver.getApiDomains(
      service: service,
      apiSourceHint: apiSource,
    );
    return domains.isNotEmpty
        ? domains
        : (apiSource == ApiSource.coomer
              ? DomainConfig.coomerApiDomains
              : DomainConfig.kemonoApiDomains);
  }

  DateTime _resolveRetryAfter(http.Response response) {
    final now = DateTime.now();
    final retryAfterRaw = response.headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'retry-after',
          orElse: () => const MapEntry('', ''),
        )
        .value
        .trim();

    if (retryAfterRaw.isEmpty) {
      return now.add(_defaultRateLimitCooldown);
    }

    final seconds = int.tryParse(retryAfterRaw);
    if (seconds != null && seconds > 0) {
      return now.add(Duration(seconds: seconds));
    }

    final retryAt = DateTime.tryParse(retryAfterRaw);
    if (retryAt != null && retryAt.isAfter(now)) {
      return retryAt;
    }

    return now.add(_defaultRateLimitCooldown);
  }
}
