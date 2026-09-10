/// Priority tiers used by the ad preloading queue.
enum AdPriority {
  /// Immediate tier for cold-boot/first-screen placements (both inline and fullscreen)
  /// and active visible screens. Drained first with top priority.
  immediate(0),

  /// High-priority placements needed early in the session.
  high(1),

  /// Medium-priority placements (recurring triggers, standard in-app placements).
  medium(2),

  /// Low-priority background preloads.
  low(3);

  final int rank;
  const AdPriority(this.rank);

  bool operator <(AdPriority other) => rank < other.rank;
  bool operator <=(AdPriority other) => rank <= other.rank;
  bool operator >(AdPriority other) => rank > other.rank;
  bool operator >=(AdPriority other) => rank >= other.rank;
}
