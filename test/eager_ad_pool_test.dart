import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/eager_ad_pool.dart';

class FakeDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;
  int showCalls = 0;

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    loadCalls++;
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

class FakeNetworkInfo implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  group('EagerAdPool Tests', () {
    late FakeDriver driver;
    late PresentationMutex mutex;
    late FakeNetworkInfo networkInfo;

    setUp(() {
      driver = FakeDriver();
      mutex = PresentationMutex();
      networkInfo = FakeNetworkInfo();
    });

    test('Entitlement Guard: Premium user bypasses all loads and shows', () {
      bool isPremiumUser = true;

      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
        isPremium: () => isPremiumUser,
      );

      const placement = InterstitialPlacement(
        id: 'interstitial',
        androidId: '1',
        iosId: '1',
      );

      // Prime all should skip
      pool.primeAll([placement]);
      expect(driver.loadCalls, 0);

      // Ready check should be false
      expect(pool.isReady(placement), false);

      // Show should bypass immediately
      bool dismissed = false;
      pool.show(placement, onDismissed: () => dismissed = true);
      expect(dismissed, true);
      expect(driver.showCalls, 0);

      pool.dispose();
    });

    test('0ms Presentation Contract: Unready ad invokes onDismissed immediately', () {
      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
      );

      const placement = InterstitialPlacement(
        id: 'unready',
        androidId: '1',
        iosId: '1',
      );

      bool dismissed = false;
      // Ad has not been loaded into pool buffer yet
      pool.show(placement, onDismissed: () => dismissed = true);

      expect(dismissed, true, reason: 'Must invoke onDismissed immediately with zero wait');
      expect(driver.showCalls, 0);

      pool.dispose();
    });

    test('Replenishment: Recurring ad auto-refills buffer; loadOnce does not', () async {
      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
      );

      const recurring = InterstitialPlacement(
        id: 'recurring',
        androidId: '1',
        iosId: '1',
        loadOnce: false,
      );

      const oneOff = InterstitialPlacement(
        id: 'one_off',
        androidId: '2',
        iosId: '2',
        loadOnce: true,
      );

      // Preload both
      await pool.preload(recurring);
      await pool.preload(oneOff);

      expect(driver.loadCalls, 2);
      expect(pool.isReady(recurring), true);
      expect(pool.isReady(oneOff), true);

      // Show recurring ad -> Dismissed -> should trigger reload
      pool.show(recurring, onDismissed: () {});
      expect(driver.showCalls, 1);
      // Wait for async replenishment preload
      await Future.delayed(const Duration(milliseconds: 20));
      expect(driver.loadCalls, 3, reason: 'Recurring placement must trigger background replenishment');

      // Show loadOnce ad -> Dismissed -> should NOT reload
      pool.show(oneOff, onDismissed: () {});
      expect(driver.showCalls, 2);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(driver.loadCalls, 3, reason: 'loadOnce placement must not replenish');

      pool.dispose();
    });

    test('Inline loadOnce: leaseInlineAd consumes placement and skips replenishment', () async {
      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
      );

      const oneOffNative = NativePlacement.big(
        id: 'splash_native',
        androidId: '3',
        iosId: '3',
        loadOnce: true,
      );

      // Preload inline ad
      await pool.preload(oneOffNative);
      expect(driver.loadCalls, 1);
      expect(pool.isReady(oneOffNative), true);

      // Lease inline ad
      final leased = pool.leaseInlineAd(oneOffNative);
      expect(leased, isNotNull);
      expect(pool.isReady(oneOffNative), false);

      // Wait for any async queue
      await Future.delayed(const Duration(milliseconds: 20));
      // driver.loadCalls should still be 1 (no replenishment!)
      expect(driver.loadCalls, 1, reason: 'Inline loadOnce must not trigger replenishment on lease');

      // Subsequent manual preload should be completely ignored
      await pool.preload(oneOffNative);
      expect(driver.loadCalls, 1, reason: 'Consumed loadOnce placement must ignore subsequent preloads');

      pool.dispose();
    });

    test('Deterministic Splash Settlement: show() awaits in-flight splash placement', () async {
      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
      );

      const splashPlacement = InterstitialPlacement(
        id: 'splash_interstitial',
        androidId: '4',
        iosId: '4',
        isSplash: true,
      );

      // Start preloading (in-flight)
      final preloadFuture = pool.preload(splashPlacement);
      expect(pool.isLoading(splashPlacement), true);

      bool dismissed = false;
      // show() called while in-flight loading
      pool.show(splashPlacement, onDismissed: () => dismissed = true);

      // Mutex should not yet be held, show awaits settlement
      expect(driver.showCalls, 0);
      expect(dismissed, false);

      // Await preload completion
      await preloadFuture;
      // Allow microtask / event loop tick for async _waitForSplashAndShow to present
      await Future.delayed(const Duration(milliseconds: 30));

      expect(driver.showCalls, 1, reason: 'Must present ad immediately once splash load settles');
      expect(dismissed, true, reason: 'Must invoke onDismissed upon presentation dismissal');

      pool.dispose();
    });

    test('waitFor returns true when ad is ready and false when premium', () async {
      bool isPremium = false;
      final pool = EagerAdPool(
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
        isPremium: () => isPremium,
      );

      const placement = InterstitialPlacement(id: 'wait_test', androidId: '5', iosId: '5');
      final loadFuture = pool.preload(placement);

      final waitFuture = pool.waitFor(placement);
      await loadFuture;
      final readyResult = await waitFuture;
      expect(readyResult, true);

      // When premium, waitFor returns false immediately
      isPremium = true;
      final premiumResult = await pool.waitFor(placement);
      expect(premiumResult, false);

      pool.dispose();
    });
  });
}
