import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/contracts/ad_network_info.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:admob_kit_flutter/src/infrastructure/appearance/native_appearance.g.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/managed_native_ad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _Driver extends GoogleMobileAdsDriver {
  final pending = <Completer<Object>>[];
  @override
  Future<Object> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    final result = Completer<Object>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Driver driver;
  late List<(NativeLayoutRequest, Completer<double>)> measurements;
  late List<int> disposals;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> boot() async {
    driver = _Driver();
    measurements = [];
    disposals = [];
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'disposeAd') disposals.add((call.arguments as Map)['adId'] as int);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(placements: [], requestConsent: false, logLevel: AdLogLevel.none),
    );
  }

  Widget host({double width = 320, double scale = 1, double? height, bool fullscreen = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: AdNativeView(
            placement: NativePlacement(
              id: 'native',
              androidId: 'test',
              iosId: 'test',
              loadOnce: true,
              template: fullscreen ? NativeAdTemplate.fullscreenMediaFirst : NativeAdTemplate.cardContentTop,
            ),
            showPlaceholder: false,
          ),
        ),
      ),
    ),
  );

  Future<ManagedNativeAd> load(WidgetTester tester) async {
    final ad = ManagedNativeAd(
      adUnitId: 'test',
      factoryId: 'test',
      request: const AdRequest(),
      listener: NativeAdListener(),
      measureLayout: (request) {
        final result = Completer<double>();
        measurements.add((request, result));
        return result.future;
      },
    )..loadedAt = DateTime.now();
    await ad.load();
    driver.pending.single.complete(ad);
    await tester.pump();
    await tester.pump();
    return ad;
  }

  tearDown(() {
    AdmobKit.dispose();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('short inline creative shrinks to measured height before mounting', (tester) async {
    await boot();
    await tester.pumpWidget(host());
    await load(tester);
    expect(find.byType(AdWidget), findsNothing);
    expect(tester.getSize(find.byType(AdNativeView)).height, NativeAdTemplate.cardContentTop.height);
    expect(measurements.single.$1.width, 320);
    expect(measurements.single.$1.height, isNull);
    expect(measurements.single.$1.headlineSize, 15);
    expect(measurements.single.$1.bodySize, 12);
    expect(measurements.single.$1.metadataSize, 11);
    expect(measurements.single.$1.actionSize, 13);
    measurements.single.$2.complete(80);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getSize(find.byType(AdNativeView)).height, 80);
    expect(AdmobKit.isShowingAd, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resize and scaled typography remeasure the same lease; stale sizes are ignored', (tester) async {
    await boot();
    await tester.pumpWidget(host());
    final ad = await load(tester);
    await tester.pumpWidget(host(width: 400, scale: 2));
    expect(measurements, hasLength(2));
    expect(measurements.last.$1.headlineSize, 30);
    expect(measurements.last.$1.bodySize, 24);
    expect(measurements.last.$1.metadataSize, 22);
    expect(measurements.last.$1.actionSize, 26);
    measurements.last.$2.complete(160);
    await tester.pump();
    await tester.pump();
    measurements.first.$2.complete(80);
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byType(AdNativeView)), const Size(400, 160));
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(driver.pending, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('inline hosts may be shorter than the loading estimate when assets fit', (tester) async {
    await boot();
    await tester.pumpWidget(host(height: 80));
    await load(tester);
    expect(tester.takeException(), isNull);
    measurements.single.$2.complete(80);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.getSize(find.byType(AdNativeView)).height, 80);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('late measurement after unmount cannot acquire or retain the SDK ad', (tester) async {
    await boot();
    await tester.pumpWidget(host(fullscreen: true, height: 600));
    await load(tester);
    expect(AdmobKit.isShowingAd, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    measurements.single.$2.complete(600);
    await tester.pump();
    await tester.pump();
    expect(AdmobKit.isShowingAd, isFalse);
    expect(disposals, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen ownership starts only after its native layout is ready', (tester) async {
    await boot();
    await tester.pumpWidget(host(fullscreen: true, height: 600));
    await load(tester);
    expect(measurements.single.$1.height, 600);
    expect(AdmobKit.isShowingAd, isFalse);
    measurements.single.$2.complete(600);
    await tester.pump();
    await tester.pump();
    expect(AdmobKit.isShowingAd, isTrue);
    expect(find.byType(AdWidget), findsOneWidget);
    expect(find.byType(CloseButton), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final invalid in [double.nan, double.infinity, -1.0, 700.0]) {
    testWidgets('invalid or overflowing measurement $invalid is never displayed', (tester) async {
      await boot();
      await tester.pumpWidget(host(fullscreen: true, height: 600));
      await load(tester);
      measurements.single.$2.complete(invalid);
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isA<FlutterError>());
      expect(find.byType(AdWidget), findsNothing);
      expect(AdmobKit.isShowingAd, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('a smaller height limit invalidates an earlier inline measurement', (tester) async {
    await boot();
    await tester.pumpWidget(host(height: 200));
    await load(tester);
    measurements.single.$2.complete(180);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(host(height: 140));
    expect(measurements, hasLength(2));
    measurements.last.$2.complete(180);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isA<FlutterError>());
    expect(find.byType(AdWidget), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
