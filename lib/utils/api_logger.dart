import 'dart:convert';

import 'logger.dart';

class ApiLogger {
  static int _counter = 0;

  static String nextRequestId() {
    _counter = (_counter + 1) % 1000000;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'req-$timestamp-$_counter';
  }

  static void request({
    required String requestId,
    required String method,
    required String url,
    Map<String, String>? headers,
    int attempt = 1,
  }) {
    AppLogger.debug(
      jsonEncode({
        'event': 'api_request',
        'requestId': requestId,
        'method': method,
        'url': url,
        'attempt': attempt,
        'headers': headers?.keys.toList(),
      }),
      tag: 'ApiLogger',
    );
  }

  static void response({
    required String requestId,
    required String method,
    required String url,
    required int statusCode,
    required Duration duration,
    String? bodySnippet,
  }) {
    AppLogger.debug(
      jsonEncode({
        'event': 'api_response',
        'requestId': requestId,
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': duration.inMilliseconds,
        'bodySnippet': bodySnippet,
      }),
      tag: 'ApiLogger',
    );
  }

  static void failure({
    required String requestId,
    required String method,
    required String url,
    required Object error,
    StackTrace? stackTrace,
    int? statusCode,
    Duration? duration,
  }) {
    AppLogger.error(
      jsonEncode({
        'event': 'api_failure',
        'requestId': requestId,
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'durationMs': duration?.inMilliseconds,
        'error': error.toString(),
      }),
      tag: 'ApiLogger',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
