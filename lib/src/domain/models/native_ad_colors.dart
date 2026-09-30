/// Optional ARGB color overrides for the built-in native templates.
///
/// Use 0xAARRGGBB values (or Flutter Color.toARGB32()). Null inherits the next
/// level: placement overrides → global colors → the template's own defaults.
/// Colors do not alter layout, ad assets, or click regions.
final class NativeAdColors {
  final int? background;
  final int? headline;

  /// Description and optional advertiser, rating and price text.
  final int? body;
  final int? callToActionBackground;
  final int? callToActionText;

  const NativeAdColors({this.background, this.headline, this.body, this.callToActionBackground, this.callToActionText});

  @override
  bool operator ==(Object other) =>
      other is NativeAdColors &&
      background == other.background &&
      headline == other.headline &&
      body == other.body &&
      callToActionBackground == other.callToActionBackground &&
      callToActionText == other.callToActionText;

  @override
  int get hashCode => Object.hash(background, headline, body, callToActionBackground, callToActionText);

  /// Validates without relying on debug-only assertions.
  void validate() {
    for (final value in [background, headline, body, callToActionBackground, callToActionText]) {
      if (value != null && (value < 0 || value > 0xffffffff)) {
        throw ArgumentError.value(value, 'color', 'Expected an unsigned 32-bit ARGB value.');
      }
    }
  }

  /// Resolves this level over inherited colors; null still means template default.
  NativeAdColors over(NativeAdColors inherited) => NativeAdColors(
    background: background ?? inherited.background,
    headline: headline ?? inherited.headline,
    body: body ?? inherited.body,
    callToActionBackground: callToActionBackground ?? inherited.callToActionBackground,
    callToActionText: callToActionText ?? inherited.callToActionText,
  );
}
