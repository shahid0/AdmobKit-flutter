import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/contracts/ad_network_info.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/adaptive_banner_ad.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/managed_native_ad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Exercise the SDK's real AdWidget ownership, with only platform transport mocked.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _Driver extends GoogleMobileAdsDriver {
  final requests = <({String id, BannerLayout? layout, Completer<dynamic> result})>[];

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    final result = Completer<dynamic>();
    requests.add((id: placement.id, layout: bannerLayout, result: result));
    return result.future;
  }
}

void main() {
  for (final native in [false, true]) {
    group(native ? 'Native host lifecycle' : 'Banner host lifecycle', () {
      late _Driver driver;
      late List<int> disposed;

      InlinePlacement placement(String id) => native
          ? NativePlacement(id: id, androidId: id, iosId: id, loadOnce: true)
          : BannerPlacement(id: id, androidId: id, iosId: id, loadOnce: true);

      Widget host({
        String id = 'first',
        bool active = true,
        bool ticker = true,
        double width = 320,
        bool landscape = false,
      }) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: landscape ? const Size(800, 400) : const Size(400, 800)),
          child: Center(
            child: SizedBox(
              width: width,
              child: TickerMode(
                enabled: ticker,
                child: native
                    ? AdNativeView(placement: placement(id) as NativePlacement, active: active, showPlaceholder: false)
                    : AdBannerView(placement: placement(id) as BannerPlacement, active: active),
              ),
            ),
          ),
        ),
      );

      Future<AdWithView> loadedAd() async {
        final AdWithView ad = native
            ? ManagedNativeAd(
                adUnitId: 'test',
                factoryId: 'test',
                measureLayout: (_) async => 104,
                request: const AdRequest(),
                listener: NativeAdListener(),
              )
            : AdaptiveBannerAd(
                adUnitId: 'test',
                size: AdSize.banner,
                request: const AdRequest(),
                listener: const BannerAdListener(),
              );
        await ad.load();
        if (ad is ManagedNativeAd) ad.loadedAt = DateTime.now();
        if (ad is AdaptiveBannerAd) {
          ad.renderSize.value = AdSize.banner;
          ad.loadedAt = DateTime.now();
        }
        return ad;
      }

      Future<void> initialize() async {
        disposed = [];
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
          if (call.method == 'disposeAd') disposed.add((call.arguments as Map)['adId'] as int);
          return null;
        });
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
        driver = _Driver();
        await AdmobKitTestHarness.initialize(
          driver: driver,
          networkInfo: _Network(),
          initializeNativeGma: false,
          config: const AdmobKitConfig(
            requestConsent: false,
            logLevel: AdLogLevel.none,
            initialConcurrency: 2,
            subsequentConcurrency: 2,
          ),
        );
      }

      tearDown(() {
        AdmobKit.dispose();
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(instanceManager.channel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      });

      testWidgets('late placement result is disposed without replacing current ad', (tester) async {
        await initialize();
        await tester.pumpWidget(host());
        await tester.pumpWidget(host(id: 'second'));
        expect(driver.requests.map((request) => request.id), ['first', 'second']);
        final current = await loadedAd();
        driver.requests[1].result.complete(current);
        await tester.pump();
        await tester.pump();
        expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(current));

        final stale = await loadedAd();
        final staleId = instanceManager.adIdFor(stale);
        driver.requests[0].result.complete(stale);
        await tester.pump();
        expect(disposed, contains(staleId));
        expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(current));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('activity gate hides loaded platform view and reuses lease on return', (tester) async {
        await initialize();
        await tester.pumpWidget(host(active: false));
        expect(driver.requests, isEmpty);
        await tester.pumpWidget(host(ticker: false));
        expect(driver.requests, isEmpty, reason: 'active cannot override TickerMode');
        await tester.pumpWidget(host());
        final ad = await loadedAd();
        driver.requests.single.result.complete(ad);
        await tester.pump();
        await tester.pump();
        expect(find.byType(AdWidget), findsOneWidget);
        await tester.pumpWidget(host(active: false));
        expect(find.byType(AdWidget), findsNothing);
        expect(disposed, isEmpty);
        await tester.pumpWidget(host());
        expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
        expect(driver.requests, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        expect(disposed, hasLength(1));
      });

      testWidgets('session disposal removes and disposes an already leased ad', (tester) async {
        await initialize();
        await tester.pumpWidget(host());
        driver.requests.single.result.complete(await loadedAd());
        await tester.pump();
        await tester.pump();
        expect(find.byType(AdWidget), findsOneWidget);
        AdmobKit.dispose();
        await tester.pump();
        expect(find.byType(AdWidget), findsNothing);
        expect(disposed, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        expect(disposed, hasLength(1));
      });

      testWidgets('load failure while inactive retries when activated', (tester) async {
        await initialize();
        await tester.pumpWidget(host());
        await tester.pumpWidget(host(active: false));
        driver.requests.single.result.completeError(LoadAdError(1, 'test', 'fatal', null));
        await tester.pump();
        await tester.pumpWidget(host());
        expect(driver.requests, hasLength(2));
        driver.requests.last.result.complete(null);
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
      });

      if (native) {
        testWidgets('expired retained native is replaced on reactivation without renewing cache age', (tester) async {
          await initialize();
          await tester.pumpWidget(host());
          final ad = await loadedAd() as ManagedNativeAd;
          final id = instanceManager.adIdFor(ad);
          driver.requests.single.result.complete(ad);
          await tester.pump();
          await tester.pump();
          ad.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
          // A theme/parent rebuild must not replace an ad currently being seen.
          await tester.pumpWidget(host());
          expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
          expect(driver.requests, hasLength(1));
          await tester.pumpWidget(host(active: false));
          expect(driver.requests, hasLength(1));
          await tester.pumpWidget(host());
          expect(disposed, contains(id));
          expect(driver.requests, hasLength(2));
          driver.requests.last.result.complete(await loadedAd());
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
        });
      }

      if (!native) {
        testWidgets('resize and orientation replace request identity, rejecting stale completion', (tester) async {
          await initialize();
          await tester.pumpWidget(host(width: 320));
          await tester.pumpWidget(host(width: 600));
          expect(driver.requests.map((request) => request.layout!.width), [320, 600]);
          final stale = await loadedAd();
          final staleId = instanceManager.adIdFor(stale);
          driver.requests[0].result.complete(stale);
          await tester.pump();
          expect(disposed, contains(staleId));
          driver.requests[1].result.complete(await loadedAd());
          await tester.pump();
          await tester.pump();
          expect(find.byType(AdWidget), findsOneWidget);
          await tester.pumpWidget(host(width: 600, landscape: true));
          expect(find.byType(AdWidget), findsNothing);
          expect(driver.requests.last.layout!.orientation, BannerOrientation.landscape);
          driver.requests.last.result.complete(await loadedAd());
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
        });

        testWidgets('expired retained banner is replaced only on reactivation', (tester) async {
          await initialize();
          await tester.pumpWidget(host());
          final ad = await loadedAd() as AdaptiveBannerAd;
          driver.requests.single.result.complete(ad);
          await tester.pump();
          await tester.pump();
          await tester.pumpWidget(host(active: false));
          ad.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
          expect(driver.requests, hasLength(1));
          await tester.pumpWidget(host());
          expect(ad.isDisposed, isTrue);
          expect(driver.requests, hasLength(2));
          driver.requests.last.result.complete(await loadedAd());
          await tester.pump();
          await tester.pumpWidget(const SizedBox());
        });
      }
    });
  }
}
