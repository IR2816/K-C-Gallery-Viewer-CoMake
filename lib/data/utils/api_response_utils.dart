import 'dart:async';

class ApiResponseUtils {
  /// Detects whether the given response body looks like HTML instead of JSON.
  static bool isHtmlResponse(String body) {
    final trimmed = body.trimLeft();
    return trimmed.startsWith('<!') ||
        trimmed.toLowerCase().startsWith('<html');
  }

  /// Unwraps common list-containing shapes into a flat list.
  /// Supports direct List responses and Map responses containing any of the
  /// provided [listKeys] (defaults to results/data/posts).
  static List<dynamic> unwrapJsonList(
    dynamic data, {
    List<String> listKeys = const ['results', 'data', 'posts'],
  }) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in listKeys) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// Maps a raw list of dynamic values to typed models with safe filtering.
  static List<T> parseList<T>(
    List<dynamic> raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return raw
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Signals that a retry should stop immediately.
  static NonRetryableException nonRetryable(Object cause) =>
      NonRetryableException(cause);

  /// Generic retry helper with optional backoff strategy.
  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxRetries = 2,
    Duration Function(int attempt)? delay,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } on NonRetryableException {
        rethrow;
      } catch (e) {
        lastError = e;
        if (attempt >= maxRetries) break;
        final wait = delay != null
            ? delay(attempt)
            : Duration(milliseconds: 400 * (1 << attempt));
        if (wait.inMilliseconds > 0) {
          await Future.delayed(wait);
        }
      }
    }
    throw lastError ?? Exception('Retry failed without an error');
  }
}

class NonRetryableException implements Exception {
  final Object cause;
  NonRetryableException(this.cause);

  @override
  String toString() => 'NonRetryableException: $cause';
}
