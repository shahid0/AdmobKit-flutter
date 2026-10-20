import 'package:flutter/foundation.dart';

import '../domain/ad_network.dart';
import '../domain/ad_placements.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/engine/ad_engine.dart';
import 'ad_session.dart';
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

  static AdEngine? get engine => activeAdSession?.engine;
  static PresentationMutex? get presentationMutex => activeAdSession?.mutex;
  static Future<void> preload(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      activeAdSession?.preload(placement, bannerLayout: bannerLayout) ?? Future<void>.value();
  static Future<dynamic> leaseInlineAd(
    InlinePlacement placement, {
    Duration? timeout,
    BannerLayout? bannerLayout,
    bool Function()? isMounted,
  }) =>
      activeAdSession?.leaseInlineAd(
        placement,
        timeout: timeout,
        bannerLayout: bannerLayout,
        isMounted: isMounted,
      ) ??
      Future<dynamic>.value(null);
}
