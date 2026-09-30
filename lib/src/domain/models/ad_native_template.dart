/// Built-in native layouts. The placement is the single source of template identity.
/// Arrangements adapted under MIT; see THIRD_PARTY_NOTICES.md.
enum NativeAdTemplate {
  /// Icon, metadata and compact pill CTA.
  small1(height: 104),

  /// No icon; metadata and compact side CTA.
  small2(height: 104),

  /// Trailing icon, metadata and compact pill CTA.
  small3(height: 104),

  /// Icon, two-line body and compact pill CTA.
  small4(height: 104),

  /// No icon; two-line body, metadata and pill CTA.
  small5(height: 104),

  /// No icon; two-line headline/body and pill CTA.
  small6(height: 104),

  /// No icon or metadata; two-line body and leading pill CTA.
  small7(height: 104),

  /// No icon or metadata; compact body and leading pill CTA.
  small8(height: 104),

  /// Media left, content and CTA right.
  medium1(height: 160),

  /// Content and CTA left, media right.
  medium2(height: 160),

  /// Icon and metadata above CTA.
  medium3(height: 160),

  /// CTA above icon and metadata.
  medium4(height: 160),

  /// Icon and body above CTA, without metadata.
  medium5(height: 160),

  /// CTA above icon and body, without metadata.
  medium6(height: 160),

  /// Media-first feed card with icon, readable copy and bottom pill CTA.
  large1(height: 340),

  /// Content, media and bottom CTA.
  large2(height: 340),

  /// Content, CTA, media.
  large3(height: 340),

  /// Right-aligned icon and content, media, bottom CTA.
  large4(height: 340),

  /// Media above content with side CTA.
  large5(height: 340),

  /// Content with side CTA above media.
  large6(height: 340),

  /// Media-first fullscreen card, content and bottom CTA.
  fullscreen1(height: 320, isFullscreen: true),

  /// Content, flexible media and bottom CTA.
  fullscreen2(height: 320, isFullscreen: true),

  /// Flexible media, trailing icon, bottom content and CTA.
  fullscreen3(height: 320, isFullscreen: true),

  /// Flexible media above content with a compact side CTA.
  fullscreen4(height: 320, isFullscreen: true),

  /// Content, CTA and flexible media.
  fullscreen5(height: 320, isFullscreen: true);

  /// Inline height, or minimum host height for a fullscreen template.
  /// Attribution shares the first asset's height; no separate header strip.
  final double height;

  /// Fills bounded host height and participates in exclusive presentation.
  final bool isFullscreen;

  /// Minimum supported logical width. Smaller hosts must choose another location.
  double get minWidth => 320;

  /// Factory identifier shared with the native catalog.
  String get factoryId => 'admobKit.$name';

  const NativeAdTemplate({required this.height, this.isFullscreen = false});
}
