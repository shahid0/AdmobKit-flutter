import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(AdmobKit.dispose);
  tearDown(AdmobKit.dispose);
  const placement = InterstitialPlacement(id: 'transition', androidId: 'test', iosId: 'test');

  test('registration before initialization fails instead of losing placements', () {
    expect(() => AdmobKit.registerPlacements([placement]), throwsStateError);
    expect(AdmobKit.initializationState, AdInitializationState.disposed);
  });

  test('show before initialization completes the app action once', () {
    var dismissals = 0;
    var displays = 0;
    AdmobKit.show(placement, onDismissed: () => dismissals++, onDisplayed: () => displays++);
    expect(dismissals, 1);
    expect(displays, 0);
  });

  test('readiness without initialization is unavailable and does not boot implicitly', () async {
    expect(await AdmobKit.waitFor(placement), isFalse);
    expect(await AdmobKit.waitUntilCanRequestAds(), isFalse);
    expect(AdmobKit.canRequestAds, isFalse);
    expect(AdmobKit.isReady(placement), isFalse);
    expect(AdmobKit.isLoading(placement), isFalse);
    expect(AdmobKit.getState(placement), AdPlacementState.unloaded);
  });

  test('native style requires an active session', () async {
    await expectLater(AdmobKit.setNativeStyle(const NativeAdStyle()), throwsStateError);
  });

  test('invalid loading configuration fails before starting initialization', () {
    for (final config in [
      const AdmobKitConfig(initialConcurrency: 0),
      const AdmobKitConfig(subsequentConcurrency: -1),
      const AdmobKitConfig(adTtl: Duration.zero),
      const AdmobKitConfig(
        timeouts: AdTimeoutConfig(inline: AdTimeoutPolicy(wifiTimeout: Duration.zero)),
      ),
    ]) {
      expect(() => AdmobKit.initialize(config: config), throwsArgumentError);
      expect(AdmobKit.initializationState, AdInitializationState.disposed);
    }
  });
}
