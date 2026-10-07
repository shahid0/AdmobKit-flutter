import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/contracts/ad_network_info.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/eager_ad_pool.dart';

class FakeDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;
  int showCalls = 0;

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async {
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

/// Driver that fails terminally (fatal error code 1 → never retried).
class _FailingDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async {
    loadCalls++;
    throw LoadAdError(1, 'invalid_request', 'FATAL invalid unit id', null);
  }
}

class _DelayedDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;
  final Duration delay;

  _DelayedDriver({required this.delay});

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async {
    loadCalls++;
    await Future.delayed(delay);
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
    onDisplayed();
    onDismissed();
  }
}

class _ManualDismissDriver extends GoogleMobileAdsDriver {
  int loadCalls = 0;
  int showCalls = 0;
  void Function()? pendingDismiss;

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async {
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
    pendingDismiss = onDismissed;
  }
}

class _TrackingMutex extends PresentationMutex {
  int attempts = 0;

  @override
  PresentationToken? tryAcquire(String holderId) {
    attempts++;
    return super.tryAcquire(holderId);
  }
}

class _PendingSplashDriver extends _ManualDismissDriver {
  final splash = Completer<dynamic>();

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) =>
      placement.isSplash ? splash.future : super.loadAd(placement, bannerLayout: bannerLayout, validateRequest: validateRequest);
}

class _ThrowingShowDriver extends FakeDriver {
  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required void Function() onDisplayed,
    required void Function() onDismissed,
    void Function(num amount, String type)? onRewardGranted,
  }) => throw StateError('platform presentation failed');
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

    testWidgets('pending splash leaves display available and rechecks mutex after loading', (tester) async {
      final driver = _PendingSplashDriver();
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);
      addTearDown(pool.dispose);
      const splash = InterstitialPlacement(id: 'splash', androidId: '1', iosId: '1', isSplash: true, loadOnce: true);
      const other = InterstitialPlacement(id: 'other', androidId: '2', iosId: '2', loadOnce: true);
      await pool.preload(other);
      pool.preload(splash);
      var dismissed = 0;
      pool.show(splash, onDismissed: () => dismissed++);
      expect(mutex.isLocked, isFalse);
      pool.show(other);
      expect(mutex.currentHolderId, 'other');
      await tester.pump();
      driver.splash.complete(Object());
      await tester.pump();
      expect(pool.isReady(splash), isTrue);
      await tester.runAsync(() async {});
      await tester.pump();
      expect(dismissed, 1);
      expect(driver.showCalls, 1);
      expect(pool.isReady(splash), isTrue, reason: 'Collision must not consume the cached ad');
      driver.pendingDismiss!();
      pool.show(splash);
      expect(driver.showCalls, 2);
      driver.pendingDismiss!();
    });

    testWidgets('disposing a pending splash settles navigation without acquiring the lock', (tester) async {
      final driver = _PendingSplashDriver();
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);
      const splash = InterstitialPlacement(id: 'splash', androidId: '1', iosId: '1', isSplash: true);
      pool.preload(splash);
      var dismissed = 0;
      pool.show(splash, onDismissed: () => dismissed++);
      pool.dispose();
      await tester.pump();
      expect(dismissed, 1);
      expect(mutex.isLocked, isFalse);
      driver.splash.complete(Object());
      await tester.pump();
      expect(driver.showCalls, 0);
      expect(dismissed, 1);
    });

    test('duplicate dismissal cannot release a newer presentation or repeat navigation', () async {
      final driver = _ManualDismissDriver();
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);
      addTearDown(pool.dispose);
      const placement = InterstitialPlacement(id: 'same', androidId: '1', iosId: '1');
      await pool.preload(placement);
      var dismissed = 0;
      pool.show(placement, onDismissed: () => dismissed++);
      final firstDismiss = driver.pendingDismiss!;
      firstDismiss();
      expect(await pool.waitFor(placement), isTrue);
      pool.show(placement);
      firstDismiss();
      expect(dismissed, 1);
      expect(mutex.isLocked, isTrue);
      driver.pendingDismiss!();
    });

    test('synchronous presentation failure releases ownership and settles navigation', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: _ThrowingShowDriver(), mutex: mutex, networkInfo: networkInfo);
      addTearDown(pool.dispose);
      const placement = InterstitialPlacement(id: 'throw', androidId: '1', iosId: '1', loadOnce: true);
      await pool.preload(placement);
      var dismissed = 0;
      pool.show(placement, onDismissed: () => dismissed++);
      expect(dismissed, 1);
      expect(mutex.isLocked, isFalse);
      expect(pool.isReady(placement), isFalse);
    });

    test('consumed empty placement skips the mutex without disturbing another ad', () async {
      final trackedMutex = _TrackingMutex();
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: trackedMutex, networkInfo: networkInfo);
      addTearDown(pool.dispose);
      const placement = InterstitialPlacement(id: 'once', androidId: '1', iosId: '1', loadOnce: true);
      await pool.preload(placement);
      pool.show(placement);
      expect(pool.isConsumed(placement), isTrue);
      expect(pool.isReady(placement), isFalse);
      expect(trackedMutex.tryAcquire('other'), isNotNull);
      final attempts = trackedMutex.attempts;
      var dismissed = 0;

      pool.show(placement, onDismissed: () => dismissed++);

      expect(dismissed, 1);
      expect(trackedMutex.attempts, attempts);
      expect(trackedMutex.currentHolderId, 'other');
      expect(driver.showCalls, 1);
    });

    test('consumed placement can still present its remaining cached ad', () async {
      final pool = EagerAdPool(
        consumedLoadOnceIds: {},
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
        placementCapacities: {'once': 2},
      );
      addTearDown(pool.dispose);
      const placement = InterstitialPlacement(id: 'once', androidId: '1', iosId: '1', loadOnce: true);
      await pool.preload(placement);
      await pool.preload(placement);
      pool.show(placement);
      expect(pool.isConsumed(placement), isTrue);
      expect(pool.isReady(placement), isTrue);

      pool.show(placement);

      expect(driver.showCalls, 2);
      expect(driver.loadCalls, 2);
      expect(pool.isReady(placement), isFalse);
    });

    test('Entitlement Guard: Premium user bypasses all loads and shows', () {
      bool isPremiumUser = true;

      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo, isPremium: () => isPremiumUser);

      const placement = InterstitialPlacement(id: 'interstitial', androidId: '1', iosId: '1');

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
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const placement = InterstitialPlacement(id: 'unready', androidId: '1', iosId: '1');

      bool dismissed = false;
      // Ad has not been loaded into pool buffer yet
      pool.show(placement, onDismissed: () => dismissed = true);

      expect(dismissed, true, reason: 'Must invoke onDismissed immediately with zero wait');
      expect(driver.showCalls, 0);

      pool.dispose();
    });

    test('Replenishment: Recurring ad auto-refills buffer; loadOnce does not', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const recurring = InterstitialPlacement(id: 'recurring', androidId: '1', iosId: '1', loadOnce: false);

      const oneOff = InterstitialPlacement(id: 'one_off', androidId: '2', iosId: '2', loadOnce: true);

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
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const oneOffNative = NativePlacement(template: NativeAdTemplate.feedMediaFirst, id: 'splash_native', androidId: '3', iosId: '3', loadOnce: true);

      // Preload inline ad
      await pool.preload(oneOffNative);
      expect(driver.loadCalls, 1);
      expect(pool.isReady(oneOffNative), true);

      // Lease inline ad
      final leased = await pool.leaseInlineAd(oneOffNative);
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
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

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
      // Allow microtask / event loop tick for async splash settlement to present
      await Future.delayed(const Duration(milliseconds: 30));

      expect(driver.showCalls, 1, reason: 'Must present ad immediately once splash load settles');
      expect(dismissed, true, reason: 'Must invoke onDismissed upon presentation dismissal');

      pool.dispose();
    });

    test('Splash settlement: concurrent show() is rejected, mutex fully released after dismissal', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const splashPlacement = InterstitialPlacement(
        id: 'splash_interstitial',
        androidId: '4',
        iosId: '4',
        isSplash: true,
      );

      final preloadFuture = pool.preload(splashPlacement);
      expect(pool.isLoading(splashPlacement), true);

      bool firstDismissed = false;
      bool secondDismissed = false;
      pool.show(splashPlacement, onDismissed: () => firstDismissed = true);
      // Concurrent trigger during settlement window: rejected deterministically.
      pool.show(splashPlacement, onDismissed: () => secondDismissed = true);

      await preloadFuture;
      await Future.delayed(const Duration(milliseconds: 30));

      expect(driver.showCalls, 1, reason: 'Exactly one presentation attempt must occur');
      expect(secondDismissed, true, reason: 'Concurrent trigger must be rejected with onDismissed');
      expect(firstDismissed, true, reason: 'Settled splash must still reach onDismissed');
      expect(mutex.isLocked, false, reason: 'Mutex must not leak after dismissal');

      pool.dispose();
    });

    test('Concurrent inline leases on empty buffer: exactly one task, both receive distinct ads', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const inlinePlacement = NativePlacement(id: 'race_native', androidId: '1', iosId: '1');

      // Two widgets race on an empty buffer: both register demand.
      final lease1 = pool.leaseInlineAd(inlinePlacement);
      final lease2 = pool.leaseInlineAd(inlinePlacement);

      // Allow the saturation-checked preloads to enqueue + settle.
      await Future.delayed(const Duration(milliseconds: 30));

      final ad1 = await lease1;
      final ad2 = await lease2;

      expect(ad1, isNotNull, reason: 'First waiter must receive an ad');
      expect(ad2, isNotNull, reason: 'Second waiter must receive its own ad (no blank view)');
      expect(identical(ad1, ad2), false, reason: 'Waiters must never share an ad instance');
      // 2 direct deliveries + 1 scheduled warm-buffer refill (target: 1).
      expect(
        driver.loadCalls,
        3,
        reason:
            'Demand leases must not storm (no per-waiter duplicate requests), '
            'but the buffer must be replenished after direct delivery',
      );
      expect(pool.isReady(inlinePlacement), true, reason: 'Buffer must be warm again for the next 0ms lease');

      pool.dispose();
    });

    test('Terminal load failure fast-fails the oldest lease waiter (no 15s placeholder hang)', () async {
      final failingDriver = _FailingDriver();
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: failingDriver, mutex: mutex, networkInfo: networkInfo);

      const inlinePlacement = NativePlacement(id: 'nofill_native', androidId: '1', iosId: '1');

      final lease = pool.leaseInlineAd(inlinePlacement);

      // Waiter must settle quickly (fast-fail), not hang until its timeout.
      final ad = await lease.timeout(const Duration(seconds: 2), onTimeout: () => 'TIMED_OUT');

      expect(ad, isNull, reason: 'Terminal failure must settle the waiter with null, not keep it hanging');
      expect(failingDriver.loadCalls, 1);

      pool.dispose();
    });

    test('Leasing and preloading from a disposed pool are safe no-ops', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);
      pool.dispose();

      const inlinePlacement = NativePlacement(id: 'disposed_native', androidId: '1', iosId: '1');

      final ad = await pool.leaseInlineAd(inlinePlacement);
      expect(ad, isNull, reason: 'Lease from disposed pool must resolve null without registering waiters');
      await pool.preload(inlinePlacement);
      expect(driver.loadCalls, 0, reason: 'Preload on disposed pool must not enqueue tasks');
    });

    test('waitFor returns true when ad is ready and false when premium', () async {
      bool isPremium = false;
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo, isPremium: () => isPremium);

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

    test('loadOnce saturation: leaseInlineAd on empty buffer does NOT trigger duplicate load', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const oneOffNative = NativePlacement(
        template: NativeAdTemplate.feedMediaFirst,
        id: 'splash_native_saturation',
        androidId: '3',
        iosId: '3',
        loadOnce: true,
      );

      // Startup prime: starts loading in background
      final preloadFuture = pool.preload(oneOffNative);
      expect(pool.isLoading(oneOffNative), true);

      // Splash mounts immediately and requests lease before buffer is filled
      final leaseFuture = pool.leaseInlineAd(oneOffNative);

      await preloadFuture;
      final ad = await leaseFuture;

      expect(ad, isNotNull);
      // Wait for any microtasks
      await Future.delayed(const Duration(milliseconds: 20));

      // Exactly 1 load call must occur! (No duplicate load triggered by openLeases)
      expect(driver.loadCalls, 1, reason: 'loadOnce must not enqueue a second load task due to openLeases');
      expect(pool.getState(oneOffNative), AdPlacementState.unloaded);

      pool.dispose();
    });

    test('show() cache miss on loadOnce or isSplash does NOT trigger background preload', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const oneOffInterstitial = InterstitialPlacement(
        id: 'one_off_interstitial',
        androidId: '10',
        iosId: '10',
        loadOnce: true,
      );

      bool dismissed = false;
      pool.show(oneOffInterstitial, onDismissed: () => dismissed = true);

      expect(dismissed, true);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(driver.loadCalls, 0, reason: '0ms cache miss on loadOnce must not fire ghost preload');
      expect(driver.showCalls, 0);

      pool.dispose();
    });

    test('Splash timeout cancels queue tasks and skips background preload', () async {
      final delayedDriver = _DelayedDriver(delay: const Duration(milliseconds: 200));
      final pool = EagerAdPool(
        consumedLoadOnceIds: {},
        driver: delayedDriver,
        mutex: mutex,
        networkInfo: networkInfo,
        timeoutConfig: const AdTimeoutConfig(
          splash: AdTimeoutPolicy(wifiTimeout: Duration(milliseconds: 30)),
          fullscreen: AdTimeoutPolicy(wifiTimeout: Duration(milliseconds: 30)),
          inline: AdTimeoutPolicy(wifiTimeout: Duration(milliseconds: 30)),
        ),
      );

      const splashGate = InterstitialPlacement(
        id: 'splash_timeout_gate',
        androidId: '11',
        iosId: '11',
        isSplash: true,
        loadOnce: true,
      );

      // Start preloading
      pool.preload(splashGate);
      expect(pool.isLoading(splashGate), true);

      bool dismissed = false;
      pool.show(splashGate, onDismissed: () => dismissed = true);

      // Wait for splash settlement to time out (30ms timeout + buffer)
      await Future.delayed(const Duration(milliseconds: 80));

      expect(dismissed, true, reason: 'Timed out splash must continue user flow');
      expect(pool.getState(splashGate), AdPlacementState.unloaded);

      // Wait past the driver's delayed load
      await Future.delayed(const Duration(milliseconds: 150));

      // Exactly 1 load call ran (the original in-flight one). No second ghost preload!
      expect(delayedDriver.loadCalls, 1, reason: 'Timed out splash must not schedule a second preload');

      pool.dispose();
    });

    test('Inline lease timeout on loadOnce stops background preload', () async {
      final hangingDriver = _DelayedDriver(delay: const Duration(seconds: 5));
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: hangingDriver, mutex: mutex, networkInfo: networkInfo);

      const oneOffNative = NativePlacement(
        id: 'onboarding_timeout_native',
        androidId: '12',
        iosId: '12',
        loadOnce: true,
      );

      final leasedAd = await pool.leaseInlineAd(oneOffNative, timeout: const Duration(milliseconds: 20));

      expect(leasedAd, isNull, reason: 'Lease must time out and return null');
      expect(pool.getState(oneOffNative), AdPlacementState.unloaded);
      expect(pool.isConsumed(oneOffNative), true);

      // Future waitFor should immediately return false
      final waitResult = await pool.waitFor(oneOffNative);
      expect(waitResult, false, reason: 'Consumed placement must immediately resolve false on waitFor');

      pool.dispose();
    });

    test('Stale eviction of loadOnce ad does NOT trigger auto-refill', () async {
      final pool = EagerAdPool(
        consumedLoadOnceIds: {},
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
        adTtl: const Duration(milliseconds: 10),
      );

      const oneOff = InterstitialPlacement(id: 'stale_one_off', androidId: '13', iosId: '13', loadOnce: true);

      await pool.preload(oneOff);
      expect(driver.loadCalls, 1);
      expect(pool.isReady(oneOff), true);

      // Wait for TTL to expire
      await Future.delayed(const Duration(milliseconds: 20));

      // Calling isReady evicts stale ad
      final ready = pool.isReady(oneOff);
      expect(ready, false);
      expect(pool.getState(oneOff), AdPlacementState.unloaded, reason: 'Stale eviction sets state to unloaded');

      await Future.delayed(const Duration(milliseconds: 20));
      // driver.loadCalls must still be 1 (NO auto-refill for loadOnce!)
      expect(driver.loadCalls, 1, reason: 'Stale eviction of loadOnce placement must not trigger refill');

      pool.dispose();
    });

    test('waitFor auto-preloads unloaded placement and resolves to ready', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const unprimed = InterstitialPlacement(id: 'unprimed_placement', androidId: '14', iosId: '14');

      // Placement was never primed. waitFor should trigger preload automatically:
      final ready = await pool.waitFor(unprimed);

      expect(ready, true, reason: 'waitFor on unprimed placement must auto-preload and settle ready');
      expect(driver.loadCalls, 1);

      pool.dispose();
    });

    test(
      'loadOnce fullscreen ad is marked consumed immediately upon show, rejecting subsequent preloads while displaying',
      () async {
        final manualDriver = _ManualDismissDriver();
        final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: manualDriver, mutex: mutex, networkInfo: networkInfo);

        const oneOff = InterstitialPlacement(
          id: 'immediate_consumed_interstitial',
          androidId: '15',
          iosId: '15',
          loadOnce: true,
        );

        await pool.preload(oneOff);
        expect(manualDriver.loadCalls, 1);
        expect(pool.isReady(oneOff), true);
        expect(pool.isConsumed(oneOff), false);

        // Trigger show - ad enters active display without dismissing yet
        pool.show(oneOff);
        expect(manualDriver.showCalls, 1);
        expect(manualDriver.pendingDismiss, isNotNull);

        // Verify immediate consumption while actively showing on screen:
        expect(pool.isConsumed(oneOff), true, reason: 'Placement must be marked consumed immediately on display');
        expect(pool.getState(oneOff), AdPlacementState.unloaded);

        // Preload attempt while displaying must be rejected:
        await pool.preload(oneOff);
        expect(manualDriver.loadCalls, 1, reason: 'Subsequent preload must be rejected while ad is displaying');

        // Dismiss the ad
        manualDriver.pendingDismiss?.call();
        await Future.delayed(const Duration(milliseconds: 20));

        expect(manualDriver.loadCalls, 1, reason: 'Dismissal must not trigger reload for loadOnce');
        expect(pool.isConsumed(oneOff), true);

        pool.dispose();
      },
    );

    test('Stale eviction of recurring ad refuels buffer without getting stuck in unloaded state', () async {
      final pool = EagerAdPool(
        consumedLoadOnceIds: {},
        driver: driver,
        mutex: mutex,
        networkInfo: networkInfo,
        adTtl: const Duration(milliseconds: 50),
      );

      const recurring = InterstitialPlacement(id: 'stale_recurring', androidId: '16', iosId: '16');

      await pool.preload(recurring);
      expect(driver.loadCalls, 1);
      expect(pool.isReady(recurring), true);

      // Wait for TTL to expire (60ms > 50ms)
      await Future.delayed(const Duration(milliseconds: 60));

      // Calling isReady evicts stale ad and triggers preload refuel:
      final ready = pool.isReady(recurring);
      expect(ready, false);

      // State must be loading (or ready after settlement), NOT stuck in unloaded!
      expect(
        pool.isLoading(recurring) || pool.isReady(recurring),
        true,
        reason: 'Placement must not get falsely stuck in unloaded state during refuel',
      );

      // Wait for refuel task to complete (10ms < 50ms TTL)
      await Future.delayed(const Duration(milliseconds: 10));
      expect(driver.loadCalls, 2);
      expect(pool.isReady(recurring), true);

      pool.dispose();
    });

    test('loadOnce fullscreen ad becomes unloaded without background refill', () async {
      final pool = EagerAdPool(consumedLoadOnceIds: {}, driver: driver, mutex: mutex, networkInfo: networkInfo);

      const oneOff = InterstitialPlacement(
        id: 'clean_transition_one_off',
        androidId: '17',
        iosId: '17',
        loadOnce: true,
      );

      await pool.preload(oneOff);
      expect(pool.isReady(oneOff), true);

      final stateEvents = <AdPlacementState>[];
      final sub = pool.watchState(oneOff).listen(stateEvents.add);

      pool.show(oneOff, onDismissed: () {});
      await Future.delayed(const Duration(milliseconds: 20));

      expect(stateEvents, [AdPlacementState.unloaded]);
      expect(driver.loadCalls, 1);

      await sub.cancel();
      pool.dispose();
    });
  });
}
