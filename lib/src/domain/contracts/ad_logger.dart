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

  final int rank;
  const AdLogLevel(this.rank);

  bool includes(AdLogLevel other) => rank <= other.rank;
}

/// Abstract logging contract for the ad engine.
abstract interface class AdLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
}
