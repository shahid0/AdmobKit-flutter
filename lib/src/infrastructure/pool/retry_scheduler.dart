import 'dart:math';

/// Calculates intelligent retry backoff intervals with jitter and error categorization.
class RetryScheduler {
  final Random _random;
  final int maxRetries;
  final Duration maxBackoff;

  RetryScheduler({
    Random? random,
    this.maxRetries = 4,
    this.maxBackoff = const Duration(seconds: 60),
  }) : _random = random ?? Random();

  /// Determines whether a retry should be scheduled based on attempt count and error code.
  bool shouldRetry({
    required int attempt,
    int? errorCode,
  }) {
    // Code 1: ERROR_CODE_INVALID_REQUEST (Fatal configuration error - wrong ID, app not approved, etc.)
    if (errorCode == 1) return false;

    return attempt < maxRetries;
  }

  /// Calculates the backoff delay duration with randomized jitter to prevent thundering herds.
  Duration calculateDelay({
    required int attempt,
    int? errorCode,
    bool isTimeout = false,
  }) {
    // Code 3: ERROR_CODE_NO_FILL (Inventory unavailable - wait moderate intervals)
    if (errorCode == 3) {
      final baseSeconds = 10 * (attempt + 1);
      final jitter = _random.nextDouble() * 3.0;
      final totalSeconds = min(baseSeconds + jitter, maxBackoff.inSeconds.toDouble());
      return Duration(milliseconds: (totalSeconds * 1000).toInt());
    }

    // Code 2 (NETWORK_ERROR), Timeout, or Unknown: Exponential backoff
    final exponent = min(attempt + 1, 6);
    final baseSeconds = pow(2, exponent).toDouble();
    final jitter = _random.nextDouble() * 2.0;
    final totalSeconds = min(baseSeconds + jitter, maxBackoff.inSeconds.toDouble());

    return Duration(milliseconds: (totalSeconds * 1000).toInt());
  }
}
