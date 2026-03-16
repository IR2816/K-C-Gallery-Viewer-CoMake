import 'package:flutter/foundation.dart' show debugPrint;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Prinsip 5: Error handling yang robust
///
/// API ini kadang:
/// - Timeout
/// - Kosong
/// - CDN beda node
///
/// Maka:
/// - Selalu fallback UI
/// - Jangan anggap data selalu ada
/// - Jangan crash kalau media gagal
class ErrorHandler {
  static const Map<String, String> _errorMessages = {
    'timeout': 'Connection timeout. Please check your internet connection.',
    'no_internet': 'No internet connection. Please check your network.',
    'server_error':
        'Server is temporarily unavailable. Please try again later.',
    'not_found': 'Content not found. It may have been removed.',
    'rate_limit': 'Too many requests. Please wait a moment.',
    'invalid_response': 'Invalid server response. Please try again.',
    'network_error': 'Network error. Please check your connection.',
    'parse_error': 'Data parsing error. Please try again.',
    'cdn_error': 'CDN error. Trying alternative source...',
    'unknown_error': 'An unexpected error occurred. Please try again.',
  };

  static const Map<String, String> _fallbackMessages = {
    'creator_not_found':
        'Creator not found. The ID may be incorrect or the creator may have been removed.',
    'posts_empty': 'No posts available for this creator.',
    'media_failed':
        'Media failed to load. You can try again or use alternative viewer.',
    'search_failed':
        'Search failed. You can try again or browse by categories.',
    'cache_failed':
        'Cache operation failed. The app will continue without caching.',
  };

  /// Determine error type from exception
  static Future<ApiError> analyzeError(dynamic error, {String? context}) async {
    debugPrint('ErrorHandler: Analyzing error - $error (context: $context)');

    if (error is http.ClientException) {
      if (error.message.contains('timeout') ||
          error.message.contains('Connection timeout')) {
        return ApiError.timeout(message: _errorMessages['timeout']!);
      }
      if (error.message.contains('no internet') ||
          error.message.contains('Network is unreachable')) {
        return ApiError.noInternet(message: _errorMessages['no_internet']!);
      }
      return ApiError.networkError(message: _errorMessages['network_error']!);
    }

    if (error is Exception) {
      final message = error.toString();

      if (message.contains('timeout')) {
        return ApiError.timeout(message: _errorMessages['timeout']!);
      }
      if (message.contains('404') || message.contains('not found')) {
        return ApiError.notFound(message: _errorMessages['not_found']!);
      }
      if (message.contains('429') || message.contains('rate limit')) {
        return ApiError.rateLimit(message: _errorMessages['rate_limit']!);
      }
      if (message.contains('500') ||
          message.contains('502') ||
          message.contains('503')) {
        return ApiError.serverError(message: _errorMessages['server_error']!);
      }
      if (message.contains('HTML') || message.contains('html')) {
        return ApiError.invalidResponse(
          message: _errorMessages['invalid_response']!,
        );
      }
      if (message.contains('JSON') || message.contains('parse')) {
        return ApiError.parseError(message: _errorMessages['parse_error']!);
      }
      if (message.contains('CDN') || message.contains('cdn')) {
        return ApiError.cdnError(message: _errorMessages['cdn_error']!);
      }
    }

    return ApiError.unknown(message: _errorMessages['unknown_error']!);
  }

  /// Check connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      debugPrint('ErrorHandler: Connectivity check failed - $e');
      return true; // Assume connected if check fails
    }
  }

  /// Safe API call with automatic retry
  static Future<T?> safeApiCall<T>(
    Future<T> Function() apiCall, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    T? fallbackValue,
    String? context,
  }) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < maxRetries) {
      attempts++;
      debugPrint(
        'ErrorHandler: API call attempt $attempts/$maxRetries (context: $context)',
      );

      try {
        final result = await apiCall();
        debugPrint('ErrorHandler: API call success on attempt $attempts');
        return result;
      } catch (e) {
        lastError = e;
        debugPrint('ErrorHandler: API call failed on attempt $attempts - $e');

        // Don't retry on certain errors
        final apiError = await analyzeError(e, context: context);
        if (apiError.type == ApiErrorType.notFound ||
            apiError.type == ApiErrorType.rateLimit) {
          break;
        }

        // Wait before retry
        if (attempts < maxRetries) {
          await Future.delayed(delay * attempts); // Exponential backoff
        }
      }
    }

    debugPrint('ErrorHandler: All $maxRetries attempts failed');
    return fallbackValue;
  }

  /// Handle media loading error with fallback
  static MediaError handleMediaError(dynamic error, String mediaUrl) {
    debugPrint('ErrorHandler: Media error for $mediaUrl - $error');

    if (error is Exception) {
      final message = error.toString().toLowerCase();

      if (message.contains('404') || message.contains('not found')) {
        return MediaError.notFound(
          url: mediaUrl,
          message: 'Media not found. It may have been removed.',
        );
      }
      if (message.contains('timeout')) {
        return MediaError.timeout(
          url: mediaUrl,
          message: 'Media loading timeout. Please check your connection.',
        );
      }
      if (message.contains('network') || message.contains('connection')) {
        return MediaError.networkError(
          url: mediaUrl,
          message: 'Network error. Please check your internet connection.',
        );
      }
      if (message.contains('format') || message.contains('unsupported')) {
        return MediaError.unsupportedFormat(
          url: mediaUrl,
          message: 'Media format not supported. Try using external player.',
        );
      }
    }

    return MediaError.unknown(
      url: mediaUrl,
      message: 'Failed to load media. You can try again.',
    );
  }

  /// Get user-friendly error message
  static String getErrorMessage(ApiError error) {
    return error.message;
  }

  /// Get fallback action suggestion
  static String getFallbackAction(ApiError error) {
    switch (error.type) {
      case ApiErrorType.timeout:
      case ApiErrorType.networkError:
        return 'Check your internet connection and try again.';
      case ApiErrorType.serverError:
        return 'Server is busy. Please try again in a few minutes.';
      case ApiErrorType.notFound:
        return 'The content may have been removed. Try searching for alternatives.';
      case ApiErrorType.rateLimit:
        return 'Please wait a moment before making more requests.';
      case ApiErrorType.cdnError:
        return 'Trying alternative CDN nodes. Please wait...';
      case ApiErrorType.parseError:
        return 'Data format error. Please try refreshing.';
      default:
        return 'Please try again or contact support if the problem persists.';
    }
  }

  /// Log error for debugging
  static void logError(
    dynamic error, {
    String? context,
    Map<String, dynamic>? extra,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'context': context,
      'error': error.toString(),
      'type': error.runtimeType.toString(),
      'extra': extra,
    };

    debugPrint('ErrorHandler: ${logEntry.toString()}');

    // In production, you might want to send this to a logging service
  }

  /// Check if error is recoverable
  static bool isRecoverable(ApiError error) {
    switch (error.type) {
      case ApiErrorType.timeout:
      case ApiErrorType.networkError:
      case ApiErrorType.serverError:
      case ApiErrorType.rateLimit:
      case ApiErrorType.cdnError:
        return true;
      case ApiErrorType.notFound:
      case ApiErrorType.parseError:
      case ApiErrorType.invalidResponse:
        return false;
      case ApiErrorType.unknown:
        return true; // Assume recoverable
    }
  }

  /// Get retry delay based on error type
  static Duration getRetryDelay(ApiError error, int attempt) {
    final baseDelay = Duration(seconds: 1);

    switch (error.type) {
      case ApiErrorType.rateLimit:
        return Duration(seconds: 30 * attempt); // Longer delay for rate limit
      case ApiErrorType.serverError:
        return Duration(
          seconds: 5 * attempt,
        ); // Moderate delay for server error
      case ApiErrorType.timeout:
      case ApiErrorType.networkError:
        return Duration(
          seconds: 2 * attempt,
        ); // Shorter delay for network issues
      default:
        return baseDelay * attempt; // Default exponential backoff
    }
  }
}

/// API Error types
enum ApiErrorType {
  timeout,
  noInternet,
  networkError,
  serverError,
  notFound,
  rateLimit,
  invalidResponse,
  parseError,
  cdnError,
  unknown,
}

/// API Error class
class ApiError {
  final ApiErrorType type;
  final String message;
  final dynamic originalError;
  final int? statusCode;

  ApiError({
    required this.type,
    required this.message,
    this.originalError,
    this.statusCode,
  });

  factory ApiError.timeout({required String message, dynamic originalError}) {
    return ApiError(
      type: ApiErrorType.timeout,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.noInternet({
    required String message,
    dynamic originalError,
  }) {
    return ApiError(
      type: ApiErrorType.noInternet,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.networkError({
    required String message,
    dynamic originalError,
  }) {
    return ApiError(
      type: ApiErrorType.networkError,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.serverError({
    required String message,
    int? statusCode,
    dynamic originalError,
  }) {
    return ApiError(
      type: ApiErrorType.serverError,
      message: message,
      statusCode: statusCode,
      originalError: originalError,
    );
  }

  factory ApiError.notFound({required String message, dynamic originalError}) {
    return ApiError(
      type: ApiErrorType.notFound,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.rateLimit({required String message, dynamic originalError}) {
    return ApiError(
      type: ApiErrorType.rateLimit,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.invalidResponse({
    required String message,
    dynamic originalError,
  }) {
    return ApiError(
      type: ApiErrorType.invalidResponse,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.parseError({
    required String message,
    dynamic originalError,
  }) {
    return ApiError(
      type: ApiErrorType.parseError,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.cdnError({required String message, dynamic originalError}) {
    return ApiError(
      type: ApiErrorType.cdnError,
      message: message,
      originalError: originalError,
    );
  }

  factory ApiError.unknown({required String message, dynamic originalError}) {
    return ApiError(
      type: ApiErrorType.unknown,
      message: message,
      originalError: originalError,
    );
  }
}

/// Media Error types
enum MediaErrorType {
  notFound,
  timeout,
  networkError,
  unsupportedFormat,
  unknown,
}

/// Media Error class
class MediaError {
  final MediaErrorType type;
  final String url;
  final String message;

  MediaError({required this.type, required this.url, required this.message});

  factory MediaError.notFound({required String url, required String message}) {
    return MediaError(
      type: MediaErrorType.notFound,
      url: url,
      message: message,
    );
  }

  factory MediaError.timeout({required String url, required String message}) {
    return MediaError(type: MediaErrorType.timeout, url: url, message: message);
  }

  factory MediaError.networkError({
    required String url,
    required String message,
  }) {
    return MediaError(
      type: MediaErrorType.networkError,
      url: url,
      message: message,
    );
  }

  factory MediaError.unsupportedFormat({
    required String url,
    required String message,
  }) {
    return MediaError(
      type: MediaErrorType.unsupportedFormat,
      url: url,
      message: message,
    );
  }

  factory MediaError.unknown({required String url, required String message}) {
    return MediaError(type: MediaErrorType.unknown, url: url, message: message);
  }
}
