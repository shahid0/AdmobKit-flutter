import '../models/diagnostic_report.dart';

/// Dependency Injection contract for opt-in production diagnostics and health telemetry.
///
/// Use this interface to stream low-level network errors, timeouts, and no-fill chains
/// to error-tracking services (e.g. Sentry, Crashlytics, Datadog).
abstract interface class AdDiagnosticsTracker {
  /// Emitted on every load attempt outcome, timeout watchdog trigger, or pool eviction.
  void onDiagnosticReport(AdDiagnosticReport report);
}
