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

  final int rank;
  const AdPriority(this.rank);

  bool operator <(AdPriority other) => rank < other.rank;
  bool operator <=(AdPriority other) => rank <= other.rank;
  bool operator >(AdPriority other) => rank > other.rank;
  bool operator >=(AdPriority other) => rank >= other.rank;
}
