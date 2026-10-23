import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _OrderDriver extends GoogleMobileAdsDriver {
  final loaded = <String>[];

  @override
  Future<dynamic> loadAd(
    AdPlacement placement, {
    BannerLayout? bannerLayout,
    void Function()? validateRequest,
  }) async {
    loaded.add(placement.id);
    return Object();
  }
}

void main() {
  const native = NativePlacement(
    id: 'onboarding_native',
    androidId: '1',
    iosId: '1',
    loadOnce: true,
  );
  const banner = BannerPlacement(
    id: 'onboarding_banner',
    androidId: '2',
    iosId: '2',
    sizing: BannerSizing.standard(),
    loadOnce: true,
  );
  const exit = InterstitialPlacement(
    id: 'onboarding_exit',
    androidId: '3',
    iosId: '3',
    loadOnce: true,
  );
  late _OrderDriver driver;

  setUp(() async {
    driver = _OrderDriver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(
        requestConsent: false,
        logLevel: AdLogLevel.none,
      ),
    );
  });

  tearDown(AdmobKit.dispose);

  test('waits for every placement and loads them in list order', () async {
    expect(await AdmobKit.waitForAll([native, banner, exit]), isTrue);
    expect(driver.loaded, [
      'onboarding_native',
      'onboarding_banner',
      'onboarding_exit',
    ]);
    expect(AdmobKit.isReady(native), isTrue);
    expect(AdmobKit.isReady(banner), isTrue);
    expect(AdmobKit.isReady(exit), isTrue);
  });

  test('rejects adaptive banners, which load on layout', () {
    const adaptive = BannerPlacement(
      id: 'anchored',
      androidId: '4',
      iosId: '4',
    );
    expect(() => AdmobKit.waitForAll([native, adaptive]), throwsArgumentError);
  });
}
