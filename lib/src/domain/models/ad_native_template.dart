/// Built-in native compositions, shared by Android and iOS.
/// Arrangements adapted under MIT; see THIRD_PARTY_NOTICES.md.
enum NativeAdTemplate {
  /// Leading icon, identity, and trailing CTA on the same row.
  /// Supplied video appears above the row; text growth never relocates the CTA.
  rowWithLeadingIcon(height: 80),

  /// Identity, trailing icon, and trailing CTA on the same row.
  rowWithTrailingIcon(height: 80),

  /// Leading CTA, icon, and identity on the same row.
  rowLeadingCta(height: 80),

  /// Compact media on the left, beside identity, metadata and action.
  /// Content is measured naturally; long copy and text scaling can grow height.
  splitMediaLeft(height: 160),

  /// Compact identity, metadata and action beside media on the right.
  splitMediaRight(height: 160),

  /// Identity above a full-width action. Supplied video follows the identity.
  cardContentTop(height: 132),

  /// Full-width action above identity. Supplied video follows the identity.
  cardActionTop(height: 132),

  /// Identity with a trailing icon, above a full-width action.
  cardContentTopTrailingIcon(height: 132),

  /// Hero media, identity, then a full-width action.
  feedMediaFirst(height: 340),

  /// Identity, hero media, then a full-width action.
  feedContentFirst(height: 340),

  /// Identity, full-width action, then hero media.
  feedActionMiddle(height: 340),

  /// Trailing-icon identity, hero media, then a full-width action.
  feedTrailingIcon(height: 340),

  /// Hero media above a leading-icon identity row with a trailing CTA.
  feedMediaTopSideCta(height: 280),

  /// Leading-icon identity row with a trailing CTA above hero media.
  feedContentTopSideCta(height: 280),

  /// Bounded hero media, identity, then a full-width action.
  fullscreenMediaFirst(height: 320, isFullscreen: true),

  /// Identity, bounded hero media, then a full-width action.
  fullscreenContentFirst(height: 320, isFullscreen: true),

  /// Identity, full-width action, then bounded hero media.
  fullscreenActionMiddle(height: 320, isFullscreen: true),

  /// Bounded hero media, trailing-icon identity, then a full-width action.
  fullscreenTrailingIcon(height: 320, isFullscreen: true),

  /// Bounded hero media above a leading-icon identity row with a trailing CTA.
  fullscreenMediaSideCta(height: 320, isFullscreen: true);

  static const compactRow = rowWithLeadingIcon;
  static const smartMedia = splitMediaLeft;
  static const stackedCard = cardContentTop;
  static const feedCard = feedMediaFirst;
  static const fullscreen = fullscreenMediaFirst;

  /// Initial loading estimate for inline hosts, not a fixed content height.
  /// Loaded ads are measured from their assets, available width and text scale.
  /// For fullscreen templates this is the minimum bounded host height.
  final double height;

  /// Fills bounded host height and participates in exclusive presentation.
  final bool isFullscreen;

  /// Minimum supported logical width. Smaller hosts must choose another location.
  double get minWidth => 320;

  /// Factory identifier shared with the native catalog.
  String get factoryId => 'admobKit.$name';

  const NativeAdTemplate({required this.height, this.isFullscreen = false});
}
