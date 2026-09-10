/// Supported advertisement formats in the package.
enum AdFormat {
  /// Rectangular banner ad displayed inline or anchored at the screen bottom.
  banner,

  /// Full-screen interstitial ad shown during natural app transitions.
  interstitial,

  /// Full-screen rewarded video ad granting in-app items upon user completion.
  rewarded,

  /// Full-screen rewarded interstitial ad combining interstitial pacing with rewarded incentives.
  rewardedInterstitial,

  /// Full-screen app open ad displayed during app cold boot or background foregrounding.
  appOpen,

  /// Highly customizable native ad matching the host application design system.
  native;

  /// Whether this format occupies the full screen.
  bool get isFullscreen =>
      this == AdFormat.interstitial ||
      this == AdFormat.rewarded ||
      this == AdFormat.rewardedInterstitial ||
      this == AdFormat.appOpen;

  /// Whether this format is an inline layout widget (banner or native).
  bool get isInline => this == AdFormat.banner || this == AdFormat.native;
}

