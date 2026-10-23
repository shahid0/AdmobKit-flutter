import 'package:flutter/widgets.dart';
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

class _Driver extends GoogleMobileAdsDriver {
  int shown = 0;

  @override
  Future<dynamic> loadAd(
    AdPlacement placement, {
    BannerLayout? bannerLayout,
    void Function()? validateRequest,
  }) async => Object();

  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required void Function() onDisplayed,
    required void Function() onDismissed,
    void Function(num amount, String type)? onRewardGranted,
  }) {
    shown++;
    onDisplayed();
    onDismissed();
  }
}

void main() {
  const appOpen = AppOpenPlacement(
    id: 'app_open',
    androidId: 'test',
    iosId: 'test',
  );
  late _Driver driver;

  Future<void> boot() async {
    driver = _Driver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(
        requestConsent: false,
        logLevel: AdLogLevel.none,
      ),
    );
    await AdmobKitTestHarness.preload(appOpen);
  }

  void leaveAndReturn(WidgetTester tester) {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  tearDown(AdmobKit.dispose);

  testWidgets('returning from a tapped ad skips the app-open ad once', (
    tester,
  ) async {
    await boot();
    driver.onAdClicked!();
    leaveAndReturn(tester);
    var dismissed = 0;
    AdmobKit.show(appOpen, onDismissed: () => dismissed++);
    expect(driver.shown, 0);
    expect(dismissed, 1);
    expect(
      AdmobKit.isReady(appOpen),
      isTrue,
      reason: 'The skipped ad stays cached for the next resume.',
    );

    leaveAndReturn(tester);
    AdmobKit.show(appOpen);
    expect(driver.shown, 1);
  });

  testWidgets(
    'a tap that returns without pausing the app does not skip a later app-open ad',
    (tester) async {
      await boot();
      driver.onAdClicked!();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      leaveAndReturn(tester);
      AdmobKit.show(appOpen);
      expect(driver.shown, 1);
    },
  );

  testWidgets('a normal return shows the app-open ad', (tester) async {
    await boot();
    leaveAndReturn(tester);
    AdmobKit.show(appOpen);
    expect(driver.shown, 1);
  });
}
