/// Lifecycle state of an ad placement within the eager preloading pool.
enum AdPlacementState {
  /// The placement has not yet been enqueued or requested.
  unloaded,

  /// The placement is currently in-flight downloading in the priority queue.
  loading,

  /// The placement is primed in memory and ready for instant 0ms presentation.
  ready,

  /// The placement failed to load (network error, timeout, or no-fill)
  /// and is awaiting autonomous exponential backoff retry.
  error,
}
