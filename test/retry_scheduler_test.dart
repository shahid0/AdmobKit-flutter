import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/src/infrastructure/pool/retry_scheduler.dart';

void main() {
  group('RetryScheduler Tests', () {
    test('Fatal ERROR_CODE_INVALID_REQUEST (Code 1) never retries', () {
      final scheduler = RetryScheduler();
      expect(scheduler.shouldRetry(attempt: 0, errorCode: 1), false);
    });

    test('NETWORK_ERROR and NO_FILL allow retries up to maxRetries', () {
      final scheduler = RetryScheduler(maxRetries: 3);

      expect(scheduler.shouldRetry(attempt: 0, errorCode: 2), true);
      expect(scheduler.shouldRetry(attempt: 1, errorCode: 2), true);
      expect(scheduler.shouldRetry(attempt: 2, errorCode: 2), true);
      expect(scheduler.shouldRetry(attempt: 3, errorCode: 2), false);
    });

    test('NO_FILL calculates moderate progressive delay', () {
      final deterministicRandom = Random(42);
      final scheduler = RetryScheduler(random: deterministicRandom);

      final delay0 = scheduler.calculateDelay(attempt: 0, errorCode: 3);
      final delay1 = scheduler.calculateDelay(attempt: 1, errorCode: 3);

      expect(delay0.inSeconds, greaterThanOrEqualTo(10));
      expect(delay1.inSeconds, greaterThanOrEqualTo(20));
    });

    test('NETWORK_ERROR calculates exponential backoff with jitter capped at maxBackoff', () {
      final scheduler = RetryScheduler(maxBackoff: const Duration(seconds: 30));

      final delay0 = scheduler.calculateDelay(attempt: 0, errorCode: 2);
      final delay1 = scheduler.calculateDelay(attempt: 1, errorCode: 2);
      final delay4 = scheduler.calculateDelay(attempt: 4, errorCode: 2);

      expect(delay0.inSeconds, greaterThanOrEqualTo(2));
      expect(delay1.inSeconds, greaterThanOrEqualTo(4));
      expect(delay4.inSeconds, lessThanOrEqualTo(30));
    });
  });
}
