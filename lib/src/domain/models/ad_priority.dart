/// Priority tiers used by the ad preloading queue.
enum AdPriority {
  /// Dedicated highest tier for cold-start / splash screen placements.
  /// Drained before any other tier. Within this tier, inline placement loads before fullscreen.
  splash(0),

  /// Immediate tier for active visible screens and top-priority in-app funnels.
  immediate(1),

  /// High-priority placements needed early in the session (e.g. onboarding, main navigation).
  high(2),

  /// Medium-priority placements (recurring triggers, standard in-app placements).
  medium(3),

  /// Low-priority background preloads.
  low(4);

  /// The numerical rank of the priority tier, where lower numbers have higher priority.
  final int rank;

  /// Creates an [AdPriority] tier with the specified [rank].
  const AdPriority(this.rank);

  /// Whether this priority is higher than [other].
  bool operator <(AdPriority other) => rank < other.rank;

  /// Whether this priority is higher than or equal to [other].
  bool operator <=(AdPriority other) => rank <= other.rank;

  /// Whether this priority is lower than [other].
  bool operator >(AdPriority other) => rank > other.rank;

  /// Whether this priority is lower than or equal to [other].
  bool operator >=(AdPriority other) => rank >= other.rank;
}
