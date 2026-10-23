import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/engine/ad_engine.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/engine/retry_scheduler.dart';

class FixtureNetwork implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class RecordingTracker implements AdAnalyticsTracker {
  int requested = 0, loaded = 0, failed = 0;
  final List<({AdPlacement placement, Duration loadTime})> loadedEvents = [];
  final List<({AdPlacement placement, String error, int? errorCode})> failedEvents = [];
  final List<AdPlacement> requestedEvents = [];

  @override
  void onAdRequested(AdPlacement p) {
    requested++;
    requestedEvents.add(p);
  }

  @override
  void onAdLoaded(AdPlacement p, Duration t) {
    loaded++;
    loadedEvents.add((placement: p, loadTime: t));
  }

  @override
  void onAdFailedToLoad(AdPlacement p, String e, int? c) {
    failed++;
    failedEvents.add((placement: p, error: e, errorCode: c));
  }

  @override
  void onAdDisplayed(AdPlacement p) {}
  @override
  void onAdDismissed(AdPlacement p) {}
  @override
  void onAdClicked(AdPlacement p) {}
  @override
  void onPaidEvent(AdPlacement p, AdRevenueValue r) {}
}

class RecordingDiagnostics implements AdDiagnosticsTracker {
  final List<AdDiagnosticReport> reports = [];

  @override
  void onDiagnosticReport(AdDiagnosticReport report) {
    reports.add(report);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PACKAGE: actual SDK load success and failure reach analytics callbacks', (tester) async {
    final tracker = RecordingTracker();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadInterstitialAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const good = InterstitialPlacement(id: 'good', androidId: 'test', iosId: 'test');
    const bad = InterstitialPlacement(id: 'bad', androidId: 'test', iosId: 'test');

    final success = pool.preload(good);
    await tester.pump();
    final goodAd = instanceManager.adFor(allocated.last) as InterstitialAd;
    goodAd.adLoadCallback.onAdLoaded(goodAd);
    await tester.pump();
    await success;
    expect(pool.isReady(good), true);

    final failure = pool.preload(bad);
    await tester.pump();
    final badAd = instanceManager.adFor(allocated.last) as InterstitialAd;
    badAd.adLoadCallback.onAdFailedToLoad(LoadAdError(1, 'test', 'fatal', null));
    await tester.pump();
    await failure;
    expect(pool.getState(bad), AdPlacementState.error);

    expect(tracker.requested, 2);
    expect(tracker.loaded, 1);
    expect(tracker.failed, 1);

    // Verify detailed callback payload contracts
    expect(tracker.loadedEvents.single.placement, good);
    expect(tracker.loadedEvents.single.loadTime, greaterThanOrEqualTo(Duration.zero));
    expect(tracker.failedEvents.single.placement, bad);
    expect(tracker.failedEvents.single.error, 'fatal');
    expect(tracker.failedEvents.single.errorCode, 1);

    pool.dispose();
    await badAd.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('native load path invokes onAdLoaded on success and onAdFailedToLoad on error', (tester) async {
    final tracker = RecordingTracker();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadNativeAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const goodNative = NativePlacement(id: 'native_good', androidId: 'test', iosId: 'test');
    const badNative = NativePlacement(id: 'native_bad', androidId: 'test', iosId: 'test');

    final success = pool.preload(goodNative);
    await tester.pump();
    final goodAd = instanceManager.adFor(allocated.last) as NativeAd;
    goodAd.listener.onAdLoaded!(goodAd);
    await tester.pump();
    await success;
    expect(pool.isReady(goodNative), true);

    final failure = pool.preload(badNative);
    await tester.pump();
    final badAd = instanceManager.adFor(allocated.last) as NativeAd;
    badAd.listener.onAdFailedToLoad!(badAd, LoadAdError(1, 'test', 'native_error', null));
    await tester.pump();
    await failure;
    expect(pool.getState(badNative), AdPlacementState.error);

    expect(tracker.requested, 2);
    expect(tracker.loaded, 1);
    expect(tracker.failed, 1);
    expect(tracker.loadedEvents.single.placement, goodNative);
    expect(tracker.loadedEvents.single.loadTime, greaterThanOrEqualTo(Duration.zero));
    expect(tracker.failedEvents.single.placement, badNative);
    expect(tracker.failedEvents.single.error, 'native_error');
    expect(tracker.failedEvents.single.errorCode, 1);

    pool.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('banner load path invokes onAdLoaded on success and onAdFailedToLoad on error', (tester) async {
    final tracker = RecordingTracker();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize') {
        return 60;
      }
      if (call.method == 'getAdSize') return const AdSize(width: 320, height: 60);
      if (call.method == 'loadBannerAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const goodBanner = BannerPlacement(id: 'banner_good', androidId: 'test', iosId: 'test');
    const badBanner = BannerPlacement(id: 'banner_bad', androidId: 'test', iosId: 'test');
    const layout = BannerLayout(width: 320, orientation: BannerOrientation.portrait);

    final success = pool.preload(goodBanner, bannerLayout: layout);
    await tester.pump();
    final goodAd = instanceManager.adFor(allocated.last) as BannerAd;
    goodAd.listener.onAdLoaded!(goodAd);
    await tester.pump();
    await success;
    expect(pool.isReady(goodBanner, bannerLayout: layout), true);

    final failure = pool.preload(badBanner, bannerLayout: layout);
    await tester.pump();
    final badAd = instanceManager.adFor(allocated.last) as BannerAd;
    badAd.listener.onAdFailedToLoad!(badAd, LoadAdError(1, 'test', 'banner_fatal', null));
    await tester.pump();
    await failure;
    expect(pool.getState(badBanner, bannerLayout: layout), AdPlacementState.error);

    expect(tracker.requested, 2);
    expect(tracker.loaded, 1);
    expect(tracker.failed, 1);
    expect(tracker.loadedEvents.single.placement, goodBanner);
    expect(tracker.loadedEvents.single.loadTime, greaterThanOrEqualTo(Duration.zero));
    expect(tracker.failedEvents.single.placement, badBanner);
    expect(tracker.failedEvents.single.error, 'banner_fatal');
    expect(tracker.failedEvents.single.errorCode, 1);

    pool.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('retryable failure followed by success emits single onAdLoaded and keeps diagnostics distinct', (tester) async {
    final tracker = RecordingTracker();
    final diagnostics = RecordingDiagnostics();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
      diagnostics: diagnostics,
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadInterstitialAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const placement = InterstitialPlacement(id: 'retry_success', androidId: 'test', iosId: 'test');

    final future = pool.preload(placement);
    await tester.pump();

    // Attempt 0 fails with retryable error (Code 2: NETWORK_ERROR)
    final firstAd = instanceManager.adFor(allocated[0]) as InterstitialAd;
    firstAd.adLoadCallback.onAdFailedToLoad(LoadAdError(2, 'test', 'transient network error', null));
    await tester.pump();

    // No analytics failure emitted on retryable attempt!
    expect(tracker.failed, 0);
    expect(tracker.loaded, 0);
    expect(tracker.requested, 1);

    // Advance clock past retry backoff
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    // Attempt 1 allocated
    expect(allocated.length, 2);
    final secondAd = instanceManager.adFor(allocated[1]) as InterstitialAd;
    secondAd.adLoadCallback.onAdLoaded(secondAd);
    await tester.pump();
    await future;

    // Settled outcome: exactly 1 requested, 1 loaded, 0 failed
    expect(tracker.requested, 1);
    expect(tracker.loaded, 1);
    expect(tracker.failed, 0);
    expect(tracker.loadedEvents.single.placement, placement);
    expect(tracker.loadedEvents.single.loadTime, greaterThanOrEqualTo(Duration.zero));

    // SDK attempt diagnostics are distinct and record all underlying attempts
    final diagnosticEvents = diagnostics.reports.map((r) => r.eventType).toList();
    expect(diagnosticEvents, [
      AdDiagnosticEventType.requested,      // Attempt 0
      AdDiagnosticEventType.failedToLoad,   // Attempt 0 failed
      AdDiagnosticEventType.retryScheduled, // Scheduled retry 1
      AdDiagnosticEventType.requested,      // Attempt 1
      AdDiagnosticEventType.loaded,         // Attempt 1 loaded
    ]);

    pool.dispose();
    await firstAd.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('retryable failure reaching retry limit emits terminal onAdFailedToLoad', (tester) async {
    final tracker = RecordingTracker();
    final diagnostics = RecordingDiagnostics();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    // Custom retry scheduler with maxRetries = 1
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
      diagnostics: diagnostics,
      retryScheduler: RetryScheduler(maxRetries: 1),
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadInterstitialAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const placement = InterstitialPlacement(id: 'retry_exhaust', androidId: 'test', iosId: 'test');

    final future = pool.preload(placement);
    await tester.pump();

    // Attempt 0 fails with retryable error
    final firstAd = instanceManager.adFor(allocated[0]) as InterstitialAd;
    firstAd.adLoadCallback.onAdFailedToLoad(LoadAdError(2, 'test', 'network err 1', null));
    await tester.pump();

    // Waiting for retry: no analytics failure yet
    expect(tracker.failed, 0);

    // Fast-forward past retry delay
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    // Attempt 1 fails (now maxRetries reached -> circuit breaker)
    expect(allocated.length, 2);
    final secondAd = instanceManager.adFor(allocated[1]) as InterstitialAd;
    secondAd.adLoadCallback.onAdFailedToLoad(LoadAdError(2, 'test', 'network err 2', null));
    await tester.pump();
    await future;

    // Terminal analytics failure emitted exactly once
    expect(tracker.requested, 1);
    expect(tracker.loaded, 0);
    expect(tracker.failed, 1);
    expect(tracker.failedEvents.single.placement, placement);
    expect(tracker.failedEvents.single.error, 'network err 2');
    expect(tracker.failedEvents.single.errorCode, 2);

    final diagnosticEvents = diagnostics.reports.map((r) => r.eventType).toList();
    expect(diagnosticEvents, [
      AdDiagnosticEventType.requested,      // Attempt 0
      AdDiagnosticEventType.failedToLoad,   // Attempt 0 failed
      AdDiagnosticEventType.retryScheduled, // Scheduled retry 1
      AdDiagnosticEventType.requested,      // Attempt 1
      AdDiagnosticEventType.failedToLoad,   // Attempt 1 failed
      AdDiagnosticEventType.circuitBroken,  // Terminal circuit breaker
    ]);

    pool.dispose();
    await firstAd.dispose();
    await secondAd.dispose();
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });

  testWidgets('timeout failure emits onAdFailedToLoad with timeout error and null code', (tester) async {
    final tracker = RecordingTracker();
    final driver = GoogleMobileAdsDriver(analytics: tracker);
    // TimeoutConfig with minimal timeout (1 millisecond) and no retries
    final pool = AdEngine(
      consumedLoadOnceIds: {},
      driver: driver,
      mutex: PresentationMutex(),
      networkInfo: FixtureNetwork(),
      analytics: tracker,
      timeoutConfig: const AdTimeoutConfig(
        fullscreen: AdTimeoutPolicy(
          wifiTimeout: Duration(milliseconds: 1),
          cellularTimeout: Duration(milliseconds: 1),
          ethernetTimeout: Duration(milliseconds: 1),
          otherTimeout: Duration(milliseconds: 1),
        ),
      ),
      retryScheduler: RetryScheduler(maxRetries: 0),
    );
    final allocated = <int>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadInterstitialAd') {
        allocated.add((call.arguments as Map)['adId'] as int);
      }
      return null;
    });

    const placement = InterstitialPlacement(id: 'timeout_placement', androidId: 'test', iosId: 'test');

    final future = pool.preload(placement);
    await tester.pump();

    // Trigger timeout without completing the ad callback
    await tester.pump(const Duration(milliseconds: 50));
    await future;

    expect(tracker.requested, 1);
    expect(tracker.loaded, 0);
    expect(tracker.failed, 1);
    expect(tracker.failedEvents.single.placement, placement);
    expect(tracker.failedEvents.single.error, contains('timed out'));
    expect(tracker.failedEvents.single.errorCode, isNull);

    pool.dispose();
    if (allocated.isNotEmpty) {
      final ad = instanceManager.adFor(allocated.last) as InterstitialAd;
      await ad.dispose();
    }
    await tester.pump();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
  });
}
