/// Standard Native Ad layout templates supported out-of-the-box by [FlutterAds].
///
/// Pre-wired with dark-themed production layouts across Android (XML/Kotlin)
/// and iOS (Auto Layout/Swift).
enum NativeAdTemplate {
  /// Large format native ad with media view, icon, headline, star rating,
  /// body, and a prominent call-to-action button.
  ///
  /// Factory ID: `'bigNativeAd'`
  /// Recommended height: `300.0` (or dynamic `screenHeight * 0.36`).
  big(
    factoryId: 'bigNativeAd',
    defaultHeight: 300.0,
    minHeight: 250.0,
  ),

  /// Horizontal list tile style native ad with media view/fallback icon,
  /// ad badge, headline, advertiser, body, and CTA button.
  ///
  /// Factory ID: `'listTileMedium'` (also aliased to `'listTile'`, `'listTiles'`)
  /// Recommended height: `130.0`.
  medium(
    factoryId: 'listTileMedium',
    defaultHeight: 130.0,
    minHeight: 120.0,
  ),

  /// Compact horizontal native ad with app icon, ad badge, headline,
  /// body text, and CTA button.
  ///
  /// Factory ID: `'smallNativeAd'`
  /// Recommended height: `74.0`.
  small(
    factoryId: 'smallNativeAd',
    defaultHeight: 74.0,
    minHeight: 64.0,
  );

  final String factoryId;
  final double defaultHeight;
  final double minHeight;

  const NativeAdTemplate({
    required this.factoryId,
    required this.defaultHeight,
    required this.minHeight,
  });
}
