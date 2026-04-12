import 'dart:async';
import 'dart:io';

abstract class ApiException implements Exception {
  final String message;
  final String? endpoint;
  final String? requestId;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;

  const ApiException(
    this.message, {
    this.endpoint,
    this.requestId,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  bool get isRetryable;

  @override
  String toString() {
    final code = statusCode != null ? ' status=$statusCode' : '';
    final id = requestId != null ? ' requestId=$requestId' : '';
    final path = endpoint != null ? ' endpoint=$endpoint' : '';
    return '$runtimeType: $message$code$id$path';
  }
}

class NetworkUnavailableException extends ApiException {
  const NetworkUnavailableException({String? endpoint, String? requestId})
    : super(
        'No internet connection available.',
        endpoint: endpoint,
        requestId: requestId,
      );

  @override
  bool get isRetryable => true;
}

class RequestTimeoutException extends ApiException {
  const RequestTimeoutException({
    required String message,
    String? endpoint,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
         message,
         endpoint: endpoint,
         requestId: requestId,
         cause: cause,
         stackTrace: stackTrace,
       );

  @override
  bool get isRetryable => true;
}

class NetworkRequestException extends ApiException {
  const NetworkRequestException({
    required String message,
    String? endpoint,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
         message,
         endpoint: endpoint,
         requestId: requestId,
         cause: cause,
         stackTrace: stackTrace,
       );

  @override
  bool get isRetryable => true;
}

class HttpStatusException extends ApiException {
  const HttpStatusException({
    required String message,
    required int statusCode,
    String? endpoint,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
         message,
         statusCode: statusCode,
         endpoint: endpoint,
         requestId: requestId,
         cause: cause,
         stackTrace: stackTrace,
       );

  bool get isServerError => (statusCode ?? 0) >= 500;

  @override
  bool get isRetryable => isServerError;
}

class RateLimitException extends ApiException {
  final DateTime retryAfter;

  const RateLimitException({
    required String message,
    required this.retryAfter,
    int statusCode = 429,
    String? endpoint,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
         message,
         statusCode: statusCode,
         endpoint: endpoint,
         requestId: requestId,
         cause: cause,
         stackTrace: stackTrace,
       );

  @override
  bool get isRetryable => true;
}

class ApiParsingException extends ApiException {
  const ApiParsingException({
    required String message,
    String? endpoint,
    String? requestId,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
         message,
         endpoint: endpoint,
         requestId: requestId,
         cause: cause,
         stackTrace: stackTrace,
       );

  @override
  bool get isRetryable => false;
}

class CircuitBreakerOpenException extends ApiException {
  final DateTime retryAfter;

  const CircuitBreakerOpenException({
    required this.retryAfter,
    String? endpoint,
    String? requestId,
  }) : super(
         'Service is temporarily unavailable due to repeated failures. Retry after cooldown.',
         endpoint: endpoint,
         requestId: requestId,
       );

  @override
  bool get isRetryable => true;
}

ApiException mapToApiException(
  Object error, {
  String? endpoint,
  String? requestId,
  StackTrace? stackTrace,
}) {
  if (error is ApiException) return error;
  if (error is TimeoutException) {
    return RequestTimeoutException(
      message: 'Request timed out.',
      endpoint: endpoint,
      requestId: requestId,
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (error is SocketException) {
    return NetworkRequestException(
      message: 'Network connection failed: ${error.message}',
      endpoint: endpoint,
      requestId: requestId,
      cause: error,
      stackTrace: stackTrace,
    );
  }
  return NetworkRequestException(
    message: 'Unexpected API error: $error',
    endpoint: endpoint,
    requestId: requestId,
    cause: error,
    stackTrace: stackTrace,
  );
}
