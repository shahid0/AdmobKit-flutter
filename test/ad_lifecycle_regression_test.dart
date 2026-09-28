import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/eager_ad_pool.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/retry_scheduler.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/tiered_ad_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

const _fullscreen = InterstitialPlacement(id: 'once', androidId: '1', iosId: '1', loadOnce: true);
const _inline = NativePlacement(id: 'inline', androidId: '2', iosId: '2', loadOnce: true);
const _timeouts = AdTimeoutConfig(
  fullscreen: AdTimeoutPolicy(wifiTimeout: Duration(milliseconds: 100)),
  inline: AdTimeoutPolicy(wifiTimeout: Duration(milliseconds: 100)),
);

class _Network implements AdNetworkInfo {
  int calls = 0;
  final Completer<AdNetworkType>? first;

  _Network([this.first]);

  @override
  Future<AdNetworkType> getNetworkType() {
    calls++;
    return calls == 1 && first != null ? first!.future : Future.value(AdNetworkType.wifi);
  }

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _Driver extends GoogleMobileAdsDriver {
  int calls = 0;
  final Completer<dynamic>? pending;
  final started = Completer<void>();

  _Driver([this.pending]);

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    calls++;
    if (!started.isCompleted) started.complete();
    return pending == null ? Object() : pending!.future;
  }
}

class _Banner extends BannerAd {
  int disposals = 0;

  _Banner()
    : super(adUnitId: 'test', size: AdSize.banner, request: const AdRequest(), listener: const BannerAdListener());

  @override
  Future<void> dispose() async {
    disposals++;
  }
}

class _Fullscreen extends AdWithoutView {
  int disposals = 0;
  final disposed = Completer<void>();

  _Fullscreen() : super(adUnitId: 'test');

  @override
  Future<void> dispose() async {
    disposals++;
    if (!disposed.isCompleted) disposed.complete();
  }
}

class _DeniedConsent extends ConsentInformation {
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener success,
    OnConsentInfoUpdateFailureListener failure,
  ) {
    failure(FormError(errorCode: 1, message: 'unavailable'));
  }

  @override
  Future<bool> canRequestAds() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('waitFor sees readiness reached during network lookup', (tester) async {
    final gate = Completer<AdNetworkType>();
    final pool = EagerAdPool(
      driver: _Driver(),
      mutex: PresentationMutex(),
      networkInfo: _Network(gate),
      timeoutConfig: _timeouts,
    );
    addTearDown(pool.dispose);

    final result = pool.waitFor(_fullscreen);
    await tester.pump();
    expect(pool.isReady(_fullscreen), isTrue);
    gate.complete(AdNetworkType.wifi);
    await tester.pump();
    expect(await result, isTrue);
  });

  test('waitFor settles false when the pool is disposed', () async {
    final pending = Completer<dynamic>();
    final driver = _Driver(pending);
    final pool = EagerAdPool(driver: driver, mutex: PresentationMutex(), networkInfo: _Network());
    final result = pool.waitFor(_fullscreen);
    await driver.started.future;
    pool.dispose();
    expect(await result, isFalse);
    final ad = _Fullscreen();
    pending.complete(ad);
    await ad.disposed.future;
    expect(ad.disposals, 1);
  });

  testWidgets('cancelling backoff settles the original future without retrying', (tester) async {
    var calls = 0;
    final queue = TieredAdQueue(
      executor: (_) async {
        calls++;
        throw Exception('network');
      },
      networkInfo: _Network(),
    );
    addTearDown(queue.dispose);
    Object? failure;
    final original = queue.enqueue(_fullscreen);
    original.catchError((Object error) {
      failure = error;
      return null;
    });
    await tester.pump();
    expect(queue.pendingTaskCount(_fullscreen.id), 1);
    expect(
      identical(queue.enqueue(_fullscreen), original),
      isTrue,
      reason: 'Backoff must retain fullscreen deduplication',
    );

    queue.cancel(_fullscreen.id);
    await tester.pump();
    expect(failure, isA<AdTaskCancelledException>());
    expect(queue.pendingTaskCount(_fullscreen.id), 0);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 1);
  });

  testWidgets('cancellation during network lookup never starts an SDK request', (tester) async {
    final gate = Completer<AdNetworkType>();
    var calls = 0;
    final queue = TieredAdQueue(
      executor: (_) async {
        calls++;
        return Object();
      },
      networkInfo: _Network(gate),
    );
    addTearDown(queue.dispose);
    final result = queue.enqueue(_fullscreen).catchError((_) => null);
    await tester.pump();
    queue.cancel(_fullscreen.id);
    await result;
    gate.complete(AdNetworkType.wifi);
    await tester.pump();
    expect(calls, 0);
  });

  for (final cancelled in [false, true]) {
    testWidgets('late SDK result after watchdog is disposed (cancelled: $cancelled)', (tester) async {
      final pending = Completer<dynamic>();
      final ad = _Banner();
      final queue = TieredAdQueue(
        executor: (_) => pending.future,
        networkInfo: _Network(),
        timeoutConfig: _timeouts,
        retryScheduler: RetryScheduler(maxRetries: 0),
      );
      addTearDown(queue.dispose);
      queue.enqueue(_inline).catchError((_) => null);
      await tester.pump();
      if (cancelled) queue.cancel(_inline.id);
      await tester.pump(const Duration(milliseconds: 101));
      pending.complete(ad);
      await tester.pump();
      expect(ad.disposals, 1);
      expect(queue.pendingTaskCount(_inline.id), 0);
    });
  }

  testWidgets('cancelled fullscreen result is disposed exactly once', (tester) async {
    final pending = Completer<dynamic>();
    final ad = _Fullscreen();
    final queue = TieredAdQueue(executor: (_) => pending.future, networkInfo: _Network());
    addTearDown(queue.dispose);
    final result = queue.enqueue(_fullscreen).catchError((_) => null);
    await tester.pump();
    queue.cancel(_fullscreen.id);
    await result;
    pending.complete(ad);
    await tester.pump();
    expect(ad.disposals, 1);
  });

  testWidgets('loadOnce serves all cached slots and reloads only on new widget demand', (tester) async {
    final driver = _Driver();
    final pool = EagerAdPool(
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: _Network(),
      placementCapacities: {_inline.id: 2},
    );
    addTearDown(pool.dispose);
    pool.primeAll([_inline]);
    await tester.pump();
    expect(driver.calls, 2);

    final first = await pool.leaseInlineAd(_inline);
    expect(pool.isReady(_inline), isTrue);
    expect(await pool.waitFor(_inline), isTrue);
    final second = await pool.leaseInlineAd(_inline);
    expect(identical(first, second), isFalse);
    expect(second, isNotNull);
    await pool.preload(_inline);
    await tester.pump();
    expect(driver.calls, 2, reason: 'Consumption must not refill the warm buffer');

    final nextScreen = pool.leaseInlineAd(_inline);
    await tester.pump();
    expect(await nextScreen, isNotNull);
    expect(driver.calls, 3, reason: 'A new visible widget can request a fresh ad');
    expect(pool.getState(_inline), AdPlacementState.unloaded);
    await tester.pump();
    expect(driver.calls, 3);
  });

  testWidgets('loadOnce still serves pending slots after first consumption', (tester) async {
    final gate = Completer<dynamic>();
    final driver = _Driver(gate);
    final pool = EagerAdPool(
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: _Network(),
      placementCapacities: {_inline.id: 2},
    );
    addTearDown(pool.dispose);
    pool.primeAll([_inline]);
    final first = pool.leaseInlineAd(_inline);
    await tester.pump();
    gate.complete(Object());
    await tester.pump();
    expect(await first, isNotNull);
    expect(pool.isReady(_inline), isTrue);
    expect(await pool.leaseInlineAd(_inline), isNotNull);
    expect(driver.calls, 2);
  });

  testWidgets('consent denial blocks all facade and direct pool request paths', (tester) async {
    final previous = ConsentInformation.instance;
    final driver = _Driver();
    ConsentInformation.instance = _DeniedConsent();
    AdmobKit.driverForTesting = driver;
    AdmobKit.networkInfoForTesting = _Network();
    addTearDown(() {
      AdmobKit.dispose();
      AdmobKit.driverForTesting = null;
      AdmobKit.networkInfoForTesting = null;
      ConsentInformation.instance = previous;
    });
    final initialized = AdmobKit.initialize(config: const AdmobKitConfig(logLevel: AdLogLevel.none));
    await tester.pump();
    await initialized;
    expect(AdmobKit.canRequestAds, isFalse);
    AdmobKit.registerPlacements([_fullscreen, _inline]);
    AdmobKit.preload(_fullscreen);
    expect(await AdmobKit.waitFor(_fullscreen), isFalse);
    expect(await AdmobKit.leaseInlineAd(_inline), isNull);
    var dismissed = false;
    AdmobKit.show(_fullscreen, onDismissed: () => dismissed = true);
    expect(dismissed, isTrue);
    AdmobKit.pool!.primeAll([_fullscreen]);
    await AdmobKit.pool!.preload(_inline);
    await tester.pump();
    expect(driver.calls, 0);
  });

  testWidgets('permission is checked again after asynchronous dispatch preparation', (tester) async {
    var allowed = true;
    final gate = Completer<AdNetworkType>();
    final driver = _Driver();
    final pool = EagerAdPool(
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: _Network(gate),
      canRequestAds: () => allowed,
    );
    addTearDown(pool.dispose);
    final preload = pool.preload(_fullscreen);
    await tester.pump();
    allowed = false;
    gate.complete(AdNetworkType.wifi);
    await tester.pump();
    await preload;
    expect(driver.calls, 0);
  });

  test('0.0.2 exhaustive state switches remain source-compatible', () {
    String label(AdPlacementState state) => switch (state) {
      AdPlacementState.unloaded => 'unloaded',
      AdPlacementState.loading => 'loading',
      AdPlacementState.ready => 'ready',
      AdPlacementState.error => 'error',
    };
    expect(AdPlacementState.values.map(label), ['unloaded', 'loading', 'ready', 'error']);
  });
}
