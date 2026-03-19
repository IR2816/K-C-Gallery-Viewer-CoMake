import 'package:flutter/foundation.dart';

/// Enhanced logging utility for better debugging
class AppLogger {
  static const String _tag = 'KemonoApp';

  /// Debug level logging
  static void debug(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      final logTag = tag ?? _tag;
      final timestamp = DateTime.now().toIso8601String();

      if (error != null) {
        debugPrint('[$timestamp] DEBUG:[$logTag] $message\nERROR: $error');
        if (stackTrace != null) {
          debugPrint('STACK TRACE:\n$stackTrace');
        }
      } else {
        debugPrint('[$timestamp] DEBUG:[$logTag] $message');
      }
    }
  }

  /// Info level logging
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final logTag = tag ?? _tag;
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] INFO:[$logTag] $message');
    }
  }

  /// Warning level logging
  static void warning(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final logTag = tag ?? _tag;
      final timestamp = DateTime.now().toIso8601String();

      if (error != null) {
        debugPrint('[$timestamp] WARNING:[$logTag] $message\nERROR: $error');
      } else {
        debugPrint('[$timestamp] WARNING:[$logTag] $message');
      }
    }
  }

  /// Error level logging
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final logTag = tag ?? _tag;
    final timestamp = DateTime.now().toIso8601String();

    debugPrint('[$timestamp] ERROR:[$logTag] $message');
    if (error != null) {
      debugPrint('ERROR DETAILS: $error');
    }
    if (stackTrace != null) {
      debugPrint('STACK TRACE:\n$stackTrace');
    }
  }

  /// Network request logging
  static void network(
    String method,
    String url, {
    Map<String, String>? headers,
    String? body,
    int? statusCode,
    String? response,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] NETWORK:[$_tag] $method $url');

      if (headers != null && headers.isNotEmpty) {
        debugPrint('HEADERS: ${headers.keys.join(', ')}');
        if (headers.containsKey('Accept')) {
          debugPrint('  Accept: ${headers['Accept']}');
        }
        if (headers.containsKey('User-Agent')) {
          debugPrint('  User-Agent: ${headers['User-Agent']}');
        }
      }

      if (body != null && body.isNotEmpty) {
        debugPrint('BODY: $body');
      }

      if (statusCode != null) {
        debugPrint('STATUS: $statusCode');
      }

      if (response != null && response.length > 200) {
        debugPrint('RESPONSE: ${response.substring(0, 200)}...');
      } else if (response != null) {
        debugPrint('RESPONSE: $response');
      }
    }
  }

  /// Media URL logging with detailed info
  static void mediaUrl(
    String type,
    String originalPath,
    String fullUrl, {
    String? apiSource,
    String? domain,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] MEDIA:[$_tag] $type URL Generated');
      debugPrint('  Original Path: $originalPath');
      debugPrint('  Full URL: $fullUrl');
      debugPrint('  API Source: ${apiSource ?? 'unknown'}');
      debugPrint('  Domain: ${domain ?? 'default'}');
    }
  }

  /// Creator info logging
  static void creator(
    String action,
    String creatorId, {
    String? name,
    String? service,
    String? apiSource,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] CREATOR:[$_tag] $action');
      debugPrint('  Creator ID: $creatorId');
      debugPrint('  Name: ${name ?? 'Loading...'}');
      debugPrint('  Service: ${service ?? 'unknown'}');
      debugPrint('  API Source: ${apiSource ?? 'unknown'}');
    }
  }

  /// Post loading logging
  static void postLoad(
    String action, {
    String? creatorId,
    String? service,
    int? count,
    String? apiSource,
  }) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('[$timestamp] POSTS:[$_tag] $action');
      debugPrint('  Creator ID: ${creatorId ?? 'N/A'}');
      debugPrint('  Service: ${service ?? 'N/A'}');
      debugPrint('  API Source: ${apiSource ?? 'unknown'}');
      debugPrint('  Count: ${count ?? 0}');
    }
  }

  /// Settings/configuration logging
  static void config(String setting, dynamic value, {String? category}) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      final cat = category != null ? '[$category]' : '';
      debugPrint('[$timestamp] CONFIG:[$_tag]$cat $setting = $value');
    }
  }
}
