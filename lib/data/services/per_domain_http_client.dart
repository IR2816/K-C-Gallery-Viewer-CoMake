import 'dart:async';

import '../exceptions/api_exceptions.dart';
import '../../domain/entities/api_source.dart';
import 'api_client.dart';

/// Maintains a dedicated [ApiClient] per domain (Kemono and Coomer).
///
/// Key benefits over a shared [ApiClient]:
/// - **Separate connection pools** — a Coomer outage cannot exhaust Kemono
///   connections and vice versa.
/// - **Independent circuit breakers** — one domain tripping its breaker has
///   zero impact on the other domain's requests.
/// - **Per-domain throttling** — at most one request every 1000 ms per domain,
///   preventing thundering-herd bursts during pagination.
class PerDomainHttpClient {
  final ApiClient _kemonoClient;
  final ApiClient _coomerClient;

  // ── Per-domain throttle chain ─────────────────────────────────────────────
  // We chain futures so that concurrent callers for the same domain are
  // queued and each one waits its turn before firing.
  Future<void> _kemonoThrottle = Future<void>.value();
  Future<void> _coomerThrottle = Future<void>.value();

  DateTime? _lastKemonoRequest;
  DateTime? _lastCoomerRequest;
  DateTime? _kemonoRateLimitedUntil;
  DateTime? _coomerRateLimitedUntil;

  static const Duration _minRequestInterval = Duration(milliseconds: 1000);

  /// Creates a [PerDomainHttpClient] with explicit [ApiClient] instances.
  ///
  /// Pass distinct [ApiClient] objects (backed by independent [http.Client]
  /// instances) to achieve true connection-pool isolation.
  PerDomainHttpClient({
    required ApiClient kemonoClient,
    required ApiClient coomerClient,
  }) : _kemonoClient = kemonoClient,
       _coomerClient = coomerClient;

  // ── Routing ───────────────────────────────────────────────────────────────

  /// Returns the dedicated [ApiClient] for [apiSource].
  ApiClient clientFor(ApiSource apiSource) =>
      apiSource == ApiSource.coomer ? _coomerClient : _kemonoClient;

  /// The last successfully-contacted domain URL across both clients.
  String? get lastSuccessfulDomain =>
      _kemonoClient.lastSuccessfulDomain ?? _coomerClient.lastSuccessfulDomain;

  // ── Throttled API helpers ─────────────────────────────────────────────────

  /// Throttled wrapper for [ApiClient.getJsonList].
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
    await _throttle(apiSource);
    try {
      return clientFor(apiSource).getJsonList(
        endpoint: endpoint,
        apiSource: apiSource,
        service: service,
        headers: headers,
        cacheKey: cacheKey,
        forceRefresh: forceRefresh,
        normalize: normalize,
        headerVariants: headerVariants,
      );
    } on RateLimitException catch (error) {
      _recordRateLimit(apiSource, error.retryAfter);
      rethrow;
    }
  }

  /// Throttled wrapper for [ApiClient.getJsonObject].
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
    await _throttle(apiSource);
    try {
      return clientFor(apiSource).getJsonObject(
        endpoint: endpoint,
        apiSource: apiSource,
        service: service,
        headers: headers,
        cacheKey: cacheKey,
        forceRefresh: forceRefresh,
        normalize: normalize,
        headerVariants: headerVariants,
      );
    } on RateLimitException catch (error) {
      _recordRateLimit(apiSource, error.retryAfter);
      rethrow;
    }
  }

  /// Clears the in-memory response cache on both domain clients.
  void clearCache() {
    _kemonoClient.clearCache();
    _coomerClient.clearCache();
  }

  /// Invalidates a specific cache key on both domain clients.
  void invalidateCacheKey(String key) {
    _kemonoClient.invalidateCacheKey(key);
    _coomerClient.invalidateCacheKey(key);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Enforces [_minRequestInterval] between outgoing requests on [apiSource].
  ///
  /// Multiple concurrent callers are chained so they take turns rather than
  /// all firing simultaneously.
  Future<void> _throttle(ApiSource apiSource) {
    if (apiSource == ApiSource.coomer) {
      final prev = _coomerThrottle;
      final completer = Completer<void>();
      _coomerThrottle = completer.future;
      return _doThrottle(prev, completer, ApiSource.coomer);
    } else {
      final prev = _kemonoThrottle;
      final completer = Completer<void>();
      _kemonoThrottle = completer.future;
      return _doThrottle(prev, completer, ApiSource.kemono);
    }
  }

  Future<void> _doThrottle(
    Future<void> prev,
    Completer<void> completer,
    ApiSource apiSource,
  ) async {
    try {
      await prev;
    } catch (_) {
      // Ignore errors from the previous call; we still proceed.
    }

    final lastRequest = apiSource == ApiSource.coomer
        ? _lastCoomerRequest
        : _lastKemonoRequest;

    if (lastRequest != null) {
      final elapsed = DateTime.now().difference(lastRequest);
      if (elapsed < _minRequestInterval) {
        await Future<void>.delayed(_minRequestInterval - elapsed);
      }
    }

    final rateLimitedUntil = apiSource == ApiSource.coomer
        ? _coomerRateLimitedUntil
        : _kemonoRateLimitedUntil;
    if (rateLimitedUntil != null && DateTime.now().isBefore(rateLimitedUntil)) {
      final remaining = rateLimitedUntil.difference(DateTime.now());
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }

    if (apiSource == ApiSource.coomer) {
      _lastCoomerRequest = DateTime.now();
    } else {
      _lastKemonoRequest = DateTime.now();
    }

    completer.complete();
  }

  void _recordRateLimit(ApiSource apiSource, DateTime retryAfter) {
    if (apiSource == ApiSource.coomer) {
      final current = _coomerRateLimitedUntil;
      _coomerRateLimitedUntil = current == null || retryAfter.isAfter(current)
          ? retryAfter
          : current;
    } else {
      final current = _kemonoRateLimitedUntil;
      _kemonoRateLimitedUntil = current == null || retryAfter.isAfter(current)
          ? retryAfter
          : current;
    }
  }
}
