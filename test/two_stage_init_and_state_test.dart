import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
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
    FlutterAds.driverForTesting = fakeDriver;
  });

  tearDown(() {
    FlutterAds.driverForTesting = null;
  });

  group('Two-Stage Initialization & State Inspection Tests', () {
    test('Stage 1: Initialize boots SDK without initial placements', () async {
      await FlutterAds.initialize(
        config: const FlutterAdsConfig(
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      expect(FlutterAds.canRequestAds, true);
      const testPlacement = InterstitialPlacement(androidId: '1', iosId: '1');
      expect(FlutterAds.isReady(testPlacement), false);
      expect(FlutterAds.getState(testPlacement), AdPlacementState.unloaded);
    });

    test('Stage 2: registerPlacements primes placements and triggers loading state', () async {
      await FlutterAds.initialize(
        config: const FlutterAdsConfig(
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

      expect(FlutterAds.getState(splashInterstitial), AdPlacementState.unloaded);

      // Register placements dynamically (e.g. from Remote Config)
      FlutterAds.registerPlacements([splashInterstitial]);

      // State is immediately tracked as loading
      expect(FlutterAds.isLoading(splashInterstitial), true);
      expect(FlutterAds.getState(splashInterstitial), AdPlacementState.loading);

      // Wait for ad to resolve
      await FlutterAds.watchState(splashInterstitial).firstWhere((s) => s == AdPlacementState.ready);
      expect(FlutterAds.isReady(splashInterstitial), true);
      expect(FlutterAds.getState(splashInterstitial), AdPlacementState.ready);
    });

    test('watchState emits stream of state changes', () async {
      await FlutterAds.initialize(
        config: const FlutterAdsConfig(
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
      final sub = FlutterAds.watchState(testPlacement).listen(states.add);

      FlutterAds.registerPlacements([testPlacement]);

      await FlutterAds.watchState(testPlacement).firstWhere((s) => s == AdPlacementState.ready);

      expect(states, contains(AdPlacementState.loading));
      expect(states, contains(AdPlacementState.ready));

      await sub.cancel();
    });
  });
}

