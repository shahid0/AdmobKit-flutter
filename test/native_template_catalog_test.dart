import 'dart:async';
import 'dart:io';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:flutter/material.dart';
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
  final requests = <AdPlacement>[];
  final pending = <Completer<Object>>[];
  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    requests.add(placement);
    final result = Completer<Object>();
    pending.add(result);
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart, Kotlin and Swift expose the same 25 unique templates', () {
    final expected = [
      for (var i = 1; i <= 8; i++) 'small$i',
      for (var i = 1; i <= 6; i++) 'medium$i',
      for (var i = 1; i <= 6; i++) 'large$i',
      for (var i = 1; i <= 5; i++) 'fullscreen$i',
    ];
    expect(NativeAdTemplate.values.map((t) => t.name), expected);
    expect(NativeAdTemplate.values.map((t) => t.factoryId).toSet(), hasLength(25));
    final kotlin = File('android/src/main/kotlin/com/example/flutter_ads/NativeTemplate.kt').readAsStringSync();
    final swift = File('ios/Classes/NativeTemplate.swift').readAsStringSync();
    expect(
      RegExp(
        r'\b(?:small|medium|large|fullscreen)\d+\b',
      ).allMatches(kotlin.split('enum class NativeTemplate {').last.split(';').first).map((m) => m[0]),
      expected,
    );
    expect(
      RegExp(
        r'\b(?:small|medium|large|fullscreen)\d+\b',
      ).allMatches(swift.split('var factoryId').first).map((m) => m[0]),
      expected,
    );
    for (final template in NativeAdTemplate.values) {
      expect(template.factoryId, 'admobKit.${template.name}');
      expect(template.minWidth, 320);
      expect(
        template.height,
        template.name.startsWith('small')
            ? 104
            : template.name.startsWith('medium')
            ? 160
            : template.isFullscreen
            ? 320
            : 340,
      );
    }
  });

  test('every placement selects its catalog factory through the real SDK driver', () async {
    final factories = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadNativeAd') {
        final args = call.arguments as Map;
        factories.add(args['factoryId'] as String);
        final ad = instanceManager.adFor(args['adId'] as int)! as NativeAd;
        expect(ad.nativeAdOptions?.adChoicesPlacement, AdChoicesPlacement.topRightCorner);
        ad.listener.onAdLoaded!(ad);
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(instanceManager.channel, null));
    final driver = GoogleMobileAdsDriver();
    for (final template in NativeAdTemplate.values) {
      final ad =
          await driver.loadAd(NativePlacement(id: template.name, androidId: 'test', iosId: 'test', template: template))
              as NativeAd;
      await ad.dispose();
    }
    expect(factories, NativeAdTemplate.values.map((t) => t.factoryId));
  });

  group('native host layout contract', () {
    late _Driver driver;
    setUp(() {
      driver = _Driver();
      AdmobKit.driverForTesting = driver;
      AdmobKit.networkInfoForTesting = _Network();
    });
    tearDown(() {
      AdmobKit.dispose();
      AdmobKit.driverForTesting = null;
      AdmobKit.networkInfoForTesting = null;
    });
    Future<void> initialize() => AdmobKit.initialize(
      config: const AdmobKitConfig(placements: [], requestConsent: false, initializeNativeGma: false),
    );
    NativePlacement placement(NativeAdTemplate template, {String id = 'native'}) =>
        NativePlacement(id: id, androidId: 'test', iosId: 'test', template: template, loadOnce: true);
    Widget host(NativePlacement placement, {double width = 320, double? height, bool active = true}) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: AdNativeView(placement: placement, active: active, showPlaceholder: false),
        ),
      ),
    );

    for (final bounds in [(319.0, 340.0), (320.0, 339.0)]) {
      testWidgets('invalid bounds $bounds fail before leasing or loading', (tester) async {
        await initialize();
        await tester.pumpWidget(host(placement(NativeAdTemplate.large1), width: bounds.$1, height: bounds.$2));
        expect(tester.takeException(), isA<FlutterError>());
        expect(driver.requests, isEmpty);
      });
    }
    testWidgets('unbounded width fails before leasing', (tester) async {
      await initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: AdNativeView(placement: placement(NativeAdTemplate.small1)),
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
      expect(driver.requests, isEmpty);
    });
    testWidgets('all inactive templates reserve their exact catalog height without requests', (tester) async {
      await initialize();
      for (final template in NativeAdTemplate.values) {
        await tester.pumpWidget(host(placement(template, id: template.name), active: false));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(AdNativeView)), Size(320, template.isFullscreen ? 600 : template.height));
      }
      expect(driver.requests, isEmpty);
    });
    testWidgets('changing template and placement invalidates the old pending lease', (tester) async {
      await initialize();
      await tester.pumpWidget(host(placement(NativeAdTemplate.small1)));
      await tester.pump();
      await tester.pumpWidget(host(placement(NativeAdTemplate.large6, id: 'large')));
      driver.pending.first.complete(Object());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AdNativeView)), const Size(320, 340));
      expect(driver.requests.map((p) => (p as NativePlacement).template), [
        NativeAdTemplate.small1,
        NativeAdTemplate.large6,
      ]);
      driver.pending.last.complete(Object());
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('changing template with the same identity rejects the incompatible reuse', (tester) async {
      await initialize();
      await tester.pumpWidget(host(placement(NativeAdTemplate.small1)));
      await tester.pump();
      await tester.pumpWidget(host(placement(NativeAdTemplate.large1)));
      expect(tester.takeException(), isArgumentError);
      expect(driver.requests, hasLength(1));
      driver.pending.first.complete(Object());
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
