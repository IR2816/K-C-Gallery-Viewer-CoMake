import 'dart:async';
import 'dart:math';

class RetryPolicy {
  final int maxAttempts;
  final Duration initialTimeout;
  final Duration retryTimeout;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration jitter;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialTimeout = const Duration(seconds: 30),
    this.retryTimeout = const Duration(seconds: 15),
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 4),
    this.jitter = const Duration(milliseconds: 300),
  }) : assert(maxAttempts >= 1);

  Duration timeoutForAttempt(int attemptIndex) {
    return attemptIndex == 0 ? initialTimeout : retryTimeout;
  }

  Duration delayForRetry(int retryNumber, Random random) {
    final safeRetry = retryNumber > 20 ? 20 : retryNumber;
    final cappedMultiplier = 1 << safeRetry;
    final raw = baseDelay.inMilliseconds * cappedMultiplier;
    final capped = raw > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : raw;
    final jitterMs = jitter.inMilliseconds <= 0
        ? 0
        : random.nextInt(jitter.inMilliseconds + 1);
    return Duration(milliseconds: capped + jitterMs);
  }
}

class HttpRetryStrategy {
  final RetryPolicy policy;
  final Random _random;

  HttpRetryStrategy({RetryPolicy? policy, Random? random})
    : policy = policy ?? const RetryPolicy(),
      _random = random ?? Random();

  Future<T> execute<T>({
    required Future<T> Function(int attemptIndex, Duration timeout) operation,
    required bool Function(Object error) isRetryable,
    void Function(int attemptIndex, Object error)? onRetry,
  }) async {
    for (var attempt = 0; attempt < policy.maxAttempts; attempt++) {
      final timeout = policy.timeoutForAttempt(attempt);
      try {
        return await operation(attempt, timeout);
      } catch (error, stackTrace) {
        final shouldRetry = attempt < policy.maxAttempts - 1 && isRetryable(error);
        if (!shouldRetry) {
          Error.throwWithStackTrace(error, stackTrace);
        }

        onRetry?.call(attempt, error);
        final delay = policy.delayForRetry(attempt, _random);
        if (delay.inMilliseconds > 0) {
          await Future<void>.delayed(delay);
        }
      }
    }

    throw StateError('Retry strategy failed without capturing an error');
  }
}
