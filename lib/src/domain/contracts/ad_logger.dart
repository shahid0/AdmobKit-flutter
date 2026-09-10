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

  /// Creates an [AdLogLevel] with the specified [rank].
  const AdLogLevel(this.rank);

  /// Whether this log level includes [other] in its output verbosity.
  bool includes(AdLogLevel other) => rank <= other.rank;
}

/// Abstract logging contract for the ad engine.
abstract interface class AdLogger {
  /// Logs a debug message with low-level details.
  void debug(String message);

  /// Logs an informational operational message.
  void info(String message);

  /// Logs a warning message regarding a recoverable issue.
  void warning(String message);

  /// Logs an error message with optional [error] details and [stackTrace].
  void error(String message, [Object? error, StackTrace? stackTrace]);
}

