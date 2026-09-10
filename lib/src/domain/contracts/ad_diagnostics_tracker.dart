import '../models/diagnostic_report.dart';

/// Dependency Injection contract for opt-in production diagnostics and health telemetry.
///
/// Use this interface to stream low-level network errors, timeouts, and no-fill chains
/// to error-tracking services (e.g. Sentry, Crashlytics, Datadog).
abstract interface class AdDiagnosticsTracker {
  /// Handles diagnostic telemetry reports emitted on load attempt outcomes, timeouts, or evictions.
  void onDiagnosticReport(AdDiagnosticReport report);
}
