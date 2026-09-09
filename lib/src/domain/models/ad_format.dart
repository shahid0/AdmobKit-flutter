/// Supported advertisement formats in the package.
enum AdFormat {
  banner,
  interstitial,
  rewarded,
  rewardedInterstitial,
  appOpen,
  native;

  /// Returns true if this format occupies the full screen.
  bool get isFullscreen =>
      this == AdFormat.interstitial ||
      this == AdFormat.rewarded ||
      this == AdFormat.rewardedInterstitial ||
      this == AdFormat.appOpen;

  /// Returns true if this format is an inline widget (banner or native).
  bool get isInline => this == AdFormat.banner || this == AdFormat.native;
}
