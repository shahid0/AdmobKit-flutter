/// Optional appearance overrides for the built-in native templates.
///
/// Use 0xAARRGGBB values (or Flutter Color.toARGB32()). Null inherits the next
/// level: placement overrides → global style → the template's own defaults.
/// Styling does not alter layout dimensions, ad assets, or click regions.
final class NativeAdStyle {
  final int? background;
  final int? headline;

  /// Description and optional advertiser, rating and price text.
  final int? body;
  final int? callToActionBackground;
  final int? callToActionText;

  /// CTA corner radius in logical pixels (Android dp / iOS points).
  /// Zero gives square corners. Null inherits; values above half the button
  /// height render as a pill. Does not change the button's size or touch area.
  final double? callToActionCornerRadius;

  const NativeAdStyle({
    this.background,
    this.headline,
    this.body,
    this.callToActionBackground,
    this.callToActionText,
    this.callToActionCornerRadius,
  });

  @override
  bool operator ==(Object other) =>
      other is NativeAdStyle &&
      background == other.background &&
      headline == other.headline &&
      body == other.body &&
      callToActionBackground == other.callToActionBackground &&
      callToActionText == other.callToActionText &&
      callToActionCornerRadius == other.callToActionCornerRadius;

  @override
  int get hashCode =>
      Object.hash(background, headline, body, callToActionBackground, callToActionText, callToActionCornerRadius);

  /// Validates without relying on debug-only assertions.
  void validate() {
    for (final value in [background, headline, body, callToActionBackground, callToActionText]) {
      if (value != null && (value < 0 || value > 0xffffffff)) {
        throw ArgumentError.value(value, 'color', 'Expected an unsigned 32-bit ARGB value.');
      }
    }
    final radius = callToActionCornerRadius;
    if (radius != null && (!radius.isFinite || radius < 0)) {
      throw ArgumentError.value(radius, 'callToActionCornerRadius', 'Expected a finite non-negative radius.');
    }
  }

  /// Resolves this level over inherited style; null still means template default.
  NativeAdStyle over(NativeAdStyle inherited) => NativeAdStyle(
    background: background ?? inherited.background,
    headline: headline ?? inherited.headline,
    body: body ?? inherited.body,
    callToActionBackground: callToActionBackground ?? inherited.callToActionBackground,
    callToActionText: callToActionText ?? inherited.callToActionText,
    callToActionCornerRadius: callToActionCornerRadius ?? inherited.callToActionCornerRadius,
  );
}
