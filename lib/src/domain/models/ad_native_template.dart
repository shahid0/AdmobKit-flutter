/// Built-in native layouts. The placement is the single source of template identity.
/// Arrangements adapted under MIT; see THIRD_PARTY_NOTICES.md.
enum NativeAdTemplate {
  /// Compact row: Icon on left, headline/body/rating, compact pill CTA on right (104dp).
  rowWithLeadingIcon(height: 104),

  /// Compact row: Headline/body/rating, compact pill CTA on right, no icon (104dp).
  rowTextOnly(height: 104),

  /// Compact row: Headline/body, trailing icon on right, compact pill CTA on right (104dp).
  rowWithTrailingIcon(height: 104),

  /// Compact row: Icon on left, 2-line body without metadata, compact pill CTA (104dp).
  rowExpandedText(height: 104),

  /// Compact row: No icon, 2-line body, rating/price metadata, pill CTA (104dp).
  rowTextOnlyExpanded(height: 104),

  /// Compact row: Clean headline and 2-line body only, pill CTA (no icon or metadata) (104dp).
  rowMinimalText(height: 104),

  /// Compact row: Leading pill CTA on left, 2-line body and headline (104dp).
  rowLeadingCta(height: 104),

  /// Compact row: Leading pill CTA on left, compact 1-line body (104dp).
  rowLeadingCtaCompact(height: 104),

  /// Split card: 120dp Media on left, content and CTA stacked on right (160dp).
  splitMediaLeft(height: 160),

  /// Split card: Content and CTA stacked on left, 120dp Media on right (160dp).
  splitMediaRight(height: 160),

  /// Stacked card: Top content row with icon and metadata, bottom full-width CTA (160dp).
  cardContentTop(height: 160),

  /// Stacked card: Top full-width CTA, bottom content row with icon and metadata (160dp).
  cardActionTop(height: 160),

  /// Stacked card: Top content row with icon, bottom full-width CTA (no metadata) (160dp).
  cardCleanContentTop(height: 160),

  /// Stacked card: Top full-width CTA, bottom content row with icon (no metadata) (160dp).
  cardCleanActionTop(height: 160),

  /// Media-first feed card: Hero media on top, readable copy middle, bottom pill CTA (340dp).
  feedMediaFirst(height: 340),

  /// Feed card: Content on top, hero media middle, bottom full-width CTA (340dp).
  feedContentFirst(height: 340),

  /// Feed card: Content on top, full-width CTA middle, hero media at bottom (340dp).
  feedActionMiddle(height: 340),

  /// Feed card: Right-aligned icon and content on top, hero media, bottom CTA (340dp).
  feedTrailingIcon(height: 340),

  /// Feed card: Media on top, bottom content row with compact side CTA (340dp).
  feedMediaTopSideCta(height: 340),

  /// Feed card: Content with compact side CTA on top, media below (340dp).
  feedContentTopSideCta(height: 340),

  /// Fullscreen: Media-first fullscreen card, content middle, bottom CTA (min 320dp).
  fullscreenMediaFirst(height: 320, isFullscreen: true),

  /// Fullscreen: Content top, flexible media middle, bottom CTA (min 320dp).
  fullscreenContentFirst(height: 320, isFullscreen: true),

  /// Fullscreen: Flexible media, trailing icon, bottom content and CTA (min 320dp).
  fullscreenTrailingIcon(height: 320, isFullscreen: true),

  /// Fullscreen: Flexible media above content with a compact side CTA (min 320dp).
  fullscreenMediaSideCta(height: 320, isFullscreen: true),

  /// Fullscreen: Content top, CTA middle, flexible media bottom (min 320dp).
  fullscreenActionMiddle(height: 320, isFullscreen: true);

  /// The 5 canonical presets:
  static const compactRow = rowWithLeadingIcon;
  static const splitMedia = splitMediaLeft;
  static const stackedCard = cardContentTop;
  static const feedCard = feedMediaFirst;
  static const fullscreen = fullscreenMediaFirst;

  /// Deprecated aliases for legacy numbered names:
  @Deprecated('Use rowWithLeadingIcon instead')
  static const small1 = rowWithLeadingIcon;
  @Deprecated('Use rowTextOnly instead')
  static const small2 = rowTextOnly;
  @Deprecated('Use rowWithTrailingIcon instead')
  static const small3 = rowWithTrailingIcon;
  @Deprecated('Use rowExpandedText instead')
  static const small4 = rowExpandedText;
  @Deprecated('Use rowTextOnlyExpanded instead')
  static const small5 = rowTextOnlyExpanded;
  @Deprecated('Use rowMinimalText instead')
  static const small6 = rowMinimalText;
  @Deprecated('Use rowLeadingCta instead')
  static const small7 = rowLeadingCta;
  @Deprecated('Use rowLeadingCtaCompact instead')
  static const small8 = rowLeadingCtaCompact;

  @Deprecated('Use splitMediaLeft instead')
  static const medium1 = splitMediaLeft;
  @Deprecated('Use splitMediaRight instead')
  static const medium2 = splitMediaRight;
  @Deprecated('Use cardContentTop instead')
  static const medium3 = cardContentTop;
  @Deprecated('Use cardActionTop instead')
  static const medium4 = cardActionTop;
  @Deprecated('Use cardCleanContentTop instead')
  static const medium5 = cardCleanContentTop;
  @Deprecated('Use cardCleanActionTop instead')
  static const medium6 = cardCleanActionTop;

  @Deprecated('Use feedMediaFirst instead')
  static const large1 = feedMediaFirst;
  @Deprecated('Use feedContentFirst instead')
  static const large2 = feedContentFirst;
  @Deprecated('Use feedActionMiddle instead')
  static const large3 = feedActionMiddle;
  @Deprecated('Use feedTrailingIcon instead')
  static const large4 = feedTrailingIcon;
  @Deprecated('Use feedMediaTopSideCta instead')
  static const large5 = feedMediaTopSideCta;
  @Deprecated('Use feedContentTopSideCta instead')
  static const large6 = feedContentTopSideCta;

  @Deprecated('Use fullscreenMediaFirst instead')
  static const fullscreen1 = fullscreenMediaFirst;
  @Deprecated('Use fullscreenContentFirst instead')
  static const fullscreen2 = fullscreenContentFirst;
  @Deprecated('Use fullscreenTrailingIcon instead')
  static const fullscreen3 = fullscreenTrailingIcon;
  @Deprecated('Use fullscreenMediaSideCta instead')
  static const fullscreen4 = fullscreenMediaSideCta;
  @Deprecated('Use fullscreenActionMiddle instead')
  static const fullscreen5 = fullscreenActionMiddle;

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
