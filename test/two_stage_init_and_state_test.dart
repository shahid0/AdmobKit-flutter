import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';

class FakeDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;
  int showCalls = 0;

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    loadCalls++;
    await Future.delayed(const Duration(milliseconds: 20));
    return Object();
  }

  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required void Function() onDisplayed,
    required void Function() onDismissed,
    void Function(num amount, String type)? onRewardGranted,
  }) {
    showCalls++;
    onDisplayed();
    onDismissed();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDriver fakeDriver;

  setUp(() {
    fakeDriver = FakeDriver();
    AdmobKit.driverForTesting = fakeDriver;
  });

  tearDown(() {
    AdmobKit.driverForTesting = null;
  });

  group('Two-Stage Initialization & State Inspection Tests', () {
    test('Stage 1: Initialize boots SDK without initial placements', () async {
      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      expect(AdmobKit.canRequestAds, true);
      const testPlacement = InterstitialPlacement(androidId: '1', iosId: '1');
      expect(AdmobKit.isReady(testPlacement), false);
      expect(AdmobKit.getState(testPlacement), AdPlacementState.unloaded);
    });

    test('Stage 2: registerPlacements primes placements and triggers loading state', () async {
      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const splashInterstitial = InterstitialPlacement(
        id: 'splash_inter',
        androidId: 'splash_inter',
        iosId: 'splash_inter',
        isSplash: true,
      );

      expect(AdmobKit.getState(splashInterstitial), AdPlacementState.unloaded);

      // Register placements dynamically (e.g. from Remote Config)
      AdmobKit.registerPlacements([splashInterstitial]);

      // State is immediately tracked as loading
      expect(AdmobKit.isLoading(splashInterstitial), true);
      expect(AdmobKit.getState(splashInterstitial), AdPlacementState.loading);

      // Wait for ad to resolve
      await AdmobKit.watchState(splashInterstitial).firstWhere((s) => s == AdPlacementState.ready);
      expect(AdmobKit.isReady(splashInterstitial), true);
      expect(AdmobKit.getState(splashInterstitial), AdPlacementState.ready);
    });

    test('watchState emits stream of state changes', () async {
      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const testPlacement = InterstitialPlacement(
        id: 'watched_placement',
        androidId: 'watched_placement',
        iosId: 'watched_placement',
      );

      final states = <AdPlacementState>[];
      final sub = AdmobKit.watchState(testPlacement).listen(states.add);

      AdmobKit.registerPlacements([testPlacement]);

      await AdmobKit.watchState(testPlacement).firstWhere((s) => s == AdPlacementState.ready);

      expect(states, contains(AdPlacementState.loading));
      expect(states, contains(AdPlacementState.ready));

      await sub.cancel();
    });
  });
}

