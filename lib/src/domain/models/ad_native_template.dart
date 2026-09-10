/// Standard Native Ad layout templates supported out-of-the-box by [AdmobKit].
///
/// Pre-wired with dark-themed production layouts across Android (XML/Kotlin)
/// and iOS (Auto Layout/Swift).
enum NativeAdTemplate {
  /// Large format native ad with media view, icon, headline, star rating,
  /// body, and a prominent call-to-action button.
  ///
  /// Factory ID: `'bigNativeAd'`
  /// Height: `300.0`. Width: `double.infinity`.
  big(
    factoryId: 'bigNativeAd',
    height: 300.0,
    width: double.infinity,
    minHeight: 250.0,
  ),

  /// Horizontal list tile style native ad with media view/fallback icon,
  /// ad badge, headline, advertiser, body, and CTA button.
  ///
  /// Factory ID: `'listTileMedium'` (also aliased to `'listTile'`, `'listTiles'`)
  /// Height: `130.0`. Width: `double.infinity`.
  medium(
    factoryId: 'listTileMedium',
    height: 130.0,
    width: double.infinity,
    minHeight: 120.0,
  ),

  /// Compact horizontal native ad with app icon, ad badge, headline,
  /// body text, and CTA button.
  ///
  /// Factory ID: `'smallNativeAd'`
  /// Height: `74.0`. Width: `double.infinity`.
  small(
    factoryId: 'smallNativeAd',
    height: 74.0,
    width: double.infinity,
    minHeight: 64.0,
  );

  /// The native platform factory identifier registered in Android/iOS.
  final String factoryId;

  /// The standard template height in density-independent pixels.
  final double height;

  /// The standard template width (defaults to [double.infinity] to fill available horizontal width).
  final double width;

  /// The minimum acceptable height threshold before layout warnings or truncation.
  final double minHeight;

  /// Backwards-compatible alias for [height].
  double get defaultHeight => height;

  /// Creates a [NativeAdTemplate] with the specified layout properties.
  const NativeAdTemplate({
    required this.factoryId,
    required this.height,
    this.width = double.infinity,
    required this.minHeight,
  });
}
