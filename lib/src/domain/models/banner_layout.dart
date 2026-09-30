/// Orientation used when resolving a banner request. Independent of Flutter UI.
enum BannerOrientation { portrait, landscape }

/// Available logical width and device orientation for an adaptive banner.
final class BannerLayout {
  final int width;
  final BannerOrientation orientation;

  const BannerLayout({required this.width, required this.orientation}) : assert(width > 0);

  void validate() {
    if (width <= 0) throw ArgumentError.value(width, 'width', 'Must be positive logical pixels');
  }

  @override
  bool operator ==(Object other) => other is BannerLayout && width == other.width && orientation == other.orientation;

  @override
  int get hashCode => Object.hash(width, orientation);

  @override
  String toString() => '${width}dp/${orientation.name}';
}
