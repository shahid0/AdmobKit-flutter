import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/drivers/managed_native_ad.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';

class Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class Driver extends GoogleMobileAdsDriver {
  final requests = <Completer<dynamic>>[];
  @override
  Future<dynamic> loadAd(AdPlacement p, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    final c = Completer<dynamic>();
    requests.add(c);
    return c.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  setUp(() {
    calls = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
  });
  tearDown(() {
    AdmobKit.dispose();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('recurring native host mounts AdWidget automatically after lease timeout and background retry', (tester) async {
    final driver = Driver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    const p = NativePlacement(id: 'feature', androidId: 'test', iosId: 'test');
    Widget host(bool active) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: AdNativeView(placement: p, active: active, showPlaceholder: false),
        ),
      ),
    );
    await tester.pumpWidget(host(true));
    expect(driver.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(driver.requests, hasLength(2));
    final ad = ManagedNativeAd(
      adUnitId: 'test',
      factoryId: 'test',
      request: const AdRequest(),
      listener: NativeAdListener(),
      measureLayout: (_) async => 104,
    );
    await ad.load();
    ad.loadedAt = DateTime.now();
    driver.requests[1].complete(ad);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));

    // Ordinary rebuild maintains the mounted ad without starting duplicate loads.
    await tester.pumpWidget(host(true));
    expect(find.byType(AdWidget), findsOneWidget);
    // The pool auto-replenishes recurring inline placements upon lease, but
    // ordinary rebuilds must not start duplicate loads.
    expect(driver.requests, hasLength(3));

    await tester.pumpWidget(const SizedBox());
    AdmobKit.dispose();
    for (final result in driver.requests) {
      if (!result.isCompleted) result.complete(null);
    }
    await tester.pump();
  });

  testWidgets('a retry started while active delivers to the host after it deactivates', (tester) async {
    final driver = Driver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    const p = NativePlacement(id: 'feature', androidId: 'test', iosId: 'test');
    Widget host(bool active) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: AdNativeView(placement: p, active: active, showPlaceholder: false),
        ),
      ),
    );
    await tester.pumpWidget(host(true));
    expect(driver.requests, hasLength(1));
    await tester.pump(const Duration(seconds: 20));
    await tester.pump();

    // Deactivate host before retry completes
    await tester.pumpWidget(host(false));
    await tester.pump(const Duration(seconds: 5));
    expect(driver.requests, hasLength(2));

    final ad = ManagedNativeAd(
      adUnitId: 'test',
      factoryId: 'test',
      request: const AdRequest(),
      listener: NativeAdListener(),
      measureLayout: (_) async => 104,
    );
    await ad.load();
    ad.loadedAt = DateTime.now();
    driver.requests[1].complete(ad);
    await tester.pump();
    await tester.pump();

    // The host keeps the ad it asked for instead of dropping it and asking again.
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(driver.requests, hasLength(3), reason: 'The third request refills the recurring buffer.');

    await tester.pumpWidget(host(true));
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));

    await tester.pumpWidget(const SizedBox());
    AdmobKit.dispose();
    for (final result in driver.requests) {
      if (!result.isCompleted) result.complete(null);
    }
    await tester.pump();
  });

  testWidgets('terminal failure produces no infinite immediate retry loop', (tester) async {
    final driver = Driver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
    const p = NativePlacement(id: 'feature', androidId: 'test', iosId: 'test');
    Widget host() => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 320,
          child: AdNativeView(placement: p, active: true, showPlaceholder: false),
        ),
      ),
    );
    await tester.pumpWidget(host());
    expect(driver.requests, hasLength(1));

    // Terminal failure on initial load
    driver.requests[0].completeError(LoadAdError(1, 'test', 'no-fill', null));
    await tester.pump();

    // Rebuilding the widget must not trigger immediate synchronous load requests
    await tester.pumpWidget(host());
    await tester.pumpWidget(host());
    expect(driver.requests, hasLength(1));
    expect(find.byType(AdWidget), findsNothing);

    await tester.pumpWidget(const SizedBox());
    AdmobKit.dispose();
    for (final result in driver.requests) {
      if (!result.isCompleted) result.complete(null);
    }
    await tester.pump();
  });
}
