/// SDK sizing policy. Inline banners reserve [maxHeight] while loading.
final class BannerSizing {
  final int? maxHeight;

  const BannerSizing.anchoredAdaptive() : maxHeight = null;

  // The argument is non-nullable; null is reserved for anchored sizing.
  // ignore: prefer_initializing_formals
  const BannerSizing.inlineAdaptive({required int maxHeight}) : assert(maxHeight >= 32), maxHeight = maxHeight;

  bool get isInline => maxHeight != null;

  @override
  bool operator ==(Object other) => other is BannerSizing && maxHeight == other.maxHeight;

  @override
  int get hashCode => maxHeight.hashCode;
}
