/// Built-in native layouts. The placement is the single source of template identity.
/// Arrangements adapted under MIT; see THIRD_PARTY_NOTICES.md.
enum NativeAdTemplate {
  /// Icon, metadata and compact side CTA.
  small1(height: 112),

  /// No icon; metadata and compact side CTA.
  small2(height: 112),

  /// Icon, metadata and tall side CTA.
  small3(height: 112),

  /// Icon, two-line body and tall side CTA.
  small4(height: 112),

  /// No icon; metadata and tall side CTA.
  small5(height: 112),

  /// No icon; two-line body and tall side CTA.
  small6(height: 112),

  /// No icon or metadata; tall side CTA.
  small7(height: 112),

  /// No icon or metadata; compact side CTA.
  small8(height: 112),

  /// Media left, content and CTA right.
  medium1(height: 180),

  /// Content and CTA left, media right.
  medium2(height: 180),

  /// Icon and metadata above CTA.
  medium3(height: 180),

  /// CTA above icon and metadata.
  medium4(height: 180),

  /// Icon and body above CTA, without metadata.
  medium5(height: 180),

  /// CTA above icon and body, without metadata.
  medium6(height: 180),

  /// Content, media, bottom CTA.
  large1(height: 360),

  /// Top CTA, content, media.
  large2(height: 360),

  /// Content, CTA, media.
  large3(height: 360),

  /// Top CTA, right-aligned icon, media.
  large4(height: 360),

  /// Media above content with side CTA.
  large5(height: 360),

  /// Content with side CTA above media.
  large6(height: 360),

  /// Content, flexible media, bottom CTA.
  fullscreen1(height: 360, isFullscreen: true),

  /// Top CTA, content, flexible media.
  fullscreen2(height: 360, isFullscreen: true),

  /// Flexible media, bottom content and CTA (no overlay over video controls).
  fullscreen3(height: 360, isFullscreen: true),

  /// Half-height media above content and CTA.
  fullscreen4(height: 360, isFullscreen: true),

  /// Top CTA, flexible media, bottom content.
  fullscreen5(height: 360, isFullscreen: true);

  /// Inline height, or minimum host height for a fullscreen template.
  /// Includes the dedicated attribution/AdChoices strip.
  final double height;

  /// Fills bounded host height and participates in exclusive presentation.
  final bool isFullscreen;

  /// Minimum supported logical width. Smaller hosts must choose another location.
  double get minWidth => 320;

  /// Factory identifier shared with the native catalog.
  String get factoryId => 'admobKit.$name';

  const NativeAdTemplate({required this.height, this.isFullscreen = false});
}
