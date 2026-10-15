import 'package:flutter/foundation.dart';
import 'ad_placements.dart';

/// Verbosity levels for ad engine logging.
enum AdLogLevel {
  /// All lifecycle events, queue telemetry, and timings.
  verbose(0),

  /// Normal operational events (loads, shows, dismissals).
  info(1),

  /// Recoverable issues (timeouts, retries, no-fills).
  warning(2),

  /// Unrecoverable or fatal configuration errors.
  error(3),

  /// Completely silent (0 console output).
  none(4);

  /// The numerical rank of the log level.
  final int rank;

  const AdLogLevel(this.rank);

  /// Whether this log level includes [other] in its output verbosity.
  bool includes(AdLogLevel other) => rank <= other.rank;
}

/// Abstract logging contract for the ad engine.
abstract interface class AdLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

/// Precision tier of the impression-level ad revenue reported by Google Mobile Ads.
enum AdRevenuePrecision {
  /// Precision is unknown.
  unknown,

  /// Revenue is an unverified estimate.
  estimated,

  /// Revenue was provided by the publisher/network.
  publisherProvided,

  /// Revenue is verified and precise down to the micro-unit.
  precise,
}

/// Immutable value object representing impression-level ad revenue.
@immutable
class AdRevenueValue {
  /// Revenue in micro-units of the currency (e.g. 1,000,000 micros = 1.00 USD).
  final int micros;

  /// ISO 4217 currency code (e.g. 'USD', 'EUR').
  final String currencyCode;

  /// The precision guarantee of this revenue value.
  final AdRevenuePrecision precision;

  const AdRevenueValue({
    required this.micros,
    required this.currencyCode,
    this.precision = AdRevenuePrecision.unknown,
  });

  /// The monetary value in standard currency units (e.g. $1.50).
  double get value => micros / 1000000.0;

  @override
  String toString() =>
      'AdRevenueValue($value $currencyCode, precision: ${precision.name})';
}

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
  final String placementId;
  final AdFormat format;
  final AdDiagnosticEventType eventType;
  final int retryAttempt;
  final Duration elapsed;
  final int? admobErrorCode;
  final String? admobErrorMessage;
  final String networkType;
  final DateTime timestamp;
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

/// Dependency Injection contract for routing ad events to product/marketing analytics.
abstract interface class AdAnalyticsTracker {
  void onAdRequested(AdPlacement placement);
  void onAdLoaded(AdPlacement placement, Duration loadTime);
  void onAdFailedToLoad(AdPlacement placement, String error, int? errorCode);
  void onAdDisplayed(AdPlacement placement);
  void onAdDismissed(AdPlacement placement);
  void onAdClicked(AdPlacement placement);
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue);
}

/// Dependency Injection contract for opt-in production diagnostics and health telemetry.
abstract interface class AdDiagnosticsTracker {
  void onDiagnosticReport(AdDiagnosticReport report);
}
