import 'package:flutter/foundation.dart';
import 'ad_format.dart';

/// Types of diagnostic events emitted by the ad engine.
enum AdDiagnosticEventType {
  /// Ad load request dispatched to the network.
  requested,

  /// Ad successfully loaded into memory.
  loaded,

  /// Ad failed to load from the network.
  failedToLoad,

  /// Ad load exceeded the network-specific timeout threshold.
  timeout,

  /// Ad scheduled for exponential backoff retry.
  retryScheduled,

  /// Retry circuit breaker tripped due to consecutive unrecoverable errors.
  circuitBroken,

  /// Stale ad evicted from memory cache after TTL expired.
  staleEvicted,

  /// Consecutive cellular timeouts detected indicating a network black hole.
  blackHoleSuspected,

  /// Ad presented on screen.
  displayed,

  /// Ad dismissed by the user.
  dismissed,
}

/// Detailed telemetry report emitted for production observability and debugging.
@immutable
class AdDiagnosticReport {
  /// The unique identifier of the placement.
  final String placementId;

  /// The ad format (interstitial, rewarded, banner, etc.).
  final AdFormat format;

  /// The diagnostic event category.
  final AdDiagnosticEventType eventType;

  /// The current retry attempt number (0 for initial load).
  final int retryAttempt;

  /// The time spent during this attempt.
  final Duration elapsed;

  /// The underlying AdMob error code if applicable (e.g. 2 = network, 3 = no fill).
  final int? admobErrorCode;

  /// The detailed AdMob error message.
  final String? admobErrorMessage;

  /// The active network type ('wifi', 'cellular', 'none', 'unknown').
  final String networkType;

  /// The timestamp when the event occurred.
  final DateTime timestamp;

  /// Additional arbitrary metadata (e.g. timeout duration, black-hole count).
  final Map<String, dynamic> metadata;

  /// Creates an [AdDiagnosticReport] telemetry event.
  AdDiagnosticReport({
    required this.placementId,
    required this.format,
    required this.eventType,
    this.retryAttempt = 0,
    required this.elapsed,
    this.admobErrorCode,
    this.admobErrorMessage,
    required this.networkType,
    DateTime? timestamp,
    this.metadata = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'AdDiagnosticReport($placementId, format: ${format.name}, '
      'event: ${eventType.name}, net: $networkType, attempt: $retryAttempt, '
      'elapsed: ${elapsed.inMilliseconds}ms, errCode: $admobErrorCode)';
}
