import 'package:flutter/foundation.dart';

import '../domain/contracts/ad_network_info.dart';
import '../domain/models/ad_placement.dart';
import '../domain/models/banner_layout.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/pool/eager_ad_pool.dart';
import 'ad_runtime.dart';
import 'config/admob_kit_config.dart';

/// Package test support. Not exported by the public library.
@visibleForTesting
abstract final class AdmobKitTestHarness {
  static Future<void> initialize({
    AdmobKitConfig config = const AdmobKitConfig(),
    GoogleMobileAdsDriver? driver,
    AdNetworkInfo? networkInfo,
    bool initializeNativeGma = true,
  }) => initializeAdSession(
    config: config,
    driver: driver,
    networkInfo: networkInfo,
    initializeNativeGma: initializeNativeGma,
  );

  static EagerAdPool? get pool => activeAdSession?.pool;
  static PresentationMutex? get presentationMutex => activeAdSession?.mutex;
  static Future<void> preload(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      activeAdSession?.preload(placement, bannerLayout: bannerLayout) ?? Future<void>.value();
  static Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) =>
      activeAdSession?.leaseInlineAd(placement, timeout: timeout, bannerLayout: bannerLayout) ??
      Future<dynamic>.value(null);
}
