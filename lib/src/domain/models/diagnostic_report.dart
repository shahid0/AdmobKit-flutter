import 'package:flutter/foundation.dart';
import 'ad_format.dart';

/// Types of diagnostic events emitted by the ad engine.
enum AdDiagnosticEventType {
  requested,
  loaded,
  failedToLoad,
  timeout,
  retryScheduled,
  circuitBroken,
  staleEvicted,
  blackHoleSuspected,
  displayed,
  dismissed,
}

/// Detailed telemetry report emitted for production observability and debugging.
@immutable
class AdDiagnosticReport {
  /// Unique identifier of the placement.
  final String placementId;

  /// Ad format (interstitial, rewarded, banner, etc.).
  final AdFormat format;

  /// Diagnostic event category.
  final AdDiagnosticEventType eventType;

  /// Current retry attempt number (0 for initial load).
  final int retryAttempt;

  /// Time spent during this attempt.
  final Duration elapsed;

  /// Underlying AdMob error code if applicable (e.g. 2 = network, 3 = no fill).
  final int? admobErrorCode;

  /// Detailed AdMob error message.
  final String? admobErrorMessage;

  /// Active network type ('wifi', 'cellular', 'none', 'unknown').
  final String networkType;

  /// Time the event occurred.
  final DateTime timestamp;

  /// Additional arbitrary metadata (e.g. timeout duration, black-hole count).
  final Map<String, dynamic> metadata;

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
