/// Built-in native compositions, shared by Android and iOS.
/// Arrangements adapted under MIT; see THIRD_PARTY_NOTICES.md.
enum NativeAdTemplate {
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

  /// Bounded hero media, identity, then a full-width action.
  fullscreenMediaFirst(height: 320, isFullscreen: true),

  /// Identity, bounded hero media, then a full-width action.
  fullscreenContentFirst(height: 320, isFullscreen: true),

  /// Identity, full-width action, then bounded hero media.
  fullscreenActionMiddle(height: 320, isFullscreen: true);

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
