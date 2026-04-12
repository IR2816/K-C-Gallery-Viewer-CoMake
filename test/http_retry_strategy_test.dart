import 'package:flutter_test/flutter_test.dart';
import 'package:kc_gallery_viewer/data/services/http_retry_strategy.dart';

void main() {
  group('HttpRetryStrategy', () {
    test('retries with exponential policy and eventually succeeds', () async {
      var attempts = 0;
      final strategy = HttpRetryStrategy(
        policy: const RetryPolicy(
          maxAttempts: 3,
          initialTimeout: Duration(seconds: 30),
          retryTimeout: Duration(seconds: 15),
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );

      final result = await strategy.execute<int>(
        operation: (_, __) async {
          attempts += 1;
          if (attempts < 3) {
            throw Exception('temporary failure');
          }
          return 42;
        },
        isRetryable: (_) => true,
      );

      expect(result, 42);
      expect(attempts, 3);
    });

    test('does not retry non-retryable errors', () async {
      var attempts = 0;
      final strategy = HttpRetryStrategy(
        policy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );

      await expectLater(
        () => strategy.execute<void>(
          operation: (_, __) async {
            attempts += 1;
            throw StateError('fatal');
          },
          isRetryable: (_) => false,
        ),
        throwsA(isA<StateError>()),
      );

      expect(attempts, 1);
    });

    test('uses initial timeout then retry timeout', () async {
      final observedTimeouts = <Duration>[];
      final strategy = HttpRetryStrategy(
        policy: const RetryPolicy(
          maxAttempts: 3,
          initialTimeout: Duration(seconds: 30),
          retryTimeout: Duration(seconds: 15),
          baseDelay: Duration.zero,
          maxDelay: Duration.zero,
          jitter: Duration.zero,
        ),
      );

      await expectLater(
        () => strategy.execute<void>(
          operation: (_, timeout) async {
            observedTimeouts.add(timeout);
            throw Exception('retry');
          },
          isRetryable: (_) => true,
        ),
        throwsException,
      );

      expect(observedTimeouts, [
        const Duration(seconds: 30),
        const Duration(seconds: 15),
        const Duration(seconds: 15),
      ]);
    });
  });
}
