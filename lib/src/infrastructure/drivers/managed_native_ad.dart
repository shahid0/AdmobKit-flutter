import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Keeps native-render ownership and the original load age with a leased ad.
final class ManagedNativeAd extends NativeAd {
  final Future<void> Function()? releaseAppearance;
  DateTime? loadedAt;
  Future<void>? _disposal;

  ManagedNativeAd({
    required super.adUnitId,
    required super.factoryId,
    required super.request,
    required super.listener,
    super.customOptions,
    super.nativeAdOptions,
    this.releaseAppearance,
  });

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    // A delayed appearance acknowledgement must not retain the SDK resource.
    await Future.wait<void>([super.dispose(), if (releaseAppearance != null) releaseAppearance!()]);
  }
}
