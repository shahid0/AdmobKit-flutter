import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// SDK banner with observable render dimensions, including SDK-managed refreshes.
final class AdaptiveBannerAd extends BannerAd {
  final ValueNotifier<AdSize?> renderSize = ValueNotifier(null);
  DateTime? loadedAt;
  bool isDisposed = false;

  AdaptiveBannerAd({required super.adUnitId, required super.size, required super.request, required super.listener});

  @override
  Future<void> dispose() async {
    if (isDisposed) return;
    isDisposed = true;
    renderSize.dispose();
    await super.dispose();
  }
}
