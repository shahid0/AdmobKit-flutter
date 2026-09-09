/// Priority tiers used by the ad preloading queue.
enum AdPriority {
  /// Immediate tier for visible inline ads (splash banner/native, active screen).
  /// Drained first with 100% bandwidth.
  immediate(0),

  /// Splash fullscreen ad (interstitial or app open).
  /// Held until splash inline ads resolve, then jumps to top priority.
  splashFullscreen(1),

  /// High-priority placements needed early in the session.
  high(2),

  /// Medium-priority placements (recurring game over rewards, primary triggers).
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
