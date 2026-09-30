import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/adaptive_banner_ad.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/eager_ad_pool.dart';
import 'package:admob_kit_flutter/src/infrastructure/pool/tiered_ad_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

const _narrow = BannerLayout(width: 320, orientation: BannerOrientation.portrait);
const _wide = BannerLayout(width: 600, orientation: BannerOrientation.landscape);
const _banner = BannerPlacement(id: 'banner', androidId: 'test', iosId: 'test', loadOnce: true);

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _Driver extends GoogleMobileAdsDriver {
  final requests = <({BannerLayout? layout, Completer<dynamic> result})>[];
  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    final result = Completer<dynamic>();
    requests.add((layout: bannerLayout, result: result));
    return result.future;
  }
}

void main() {
  group('Adaptive SDK sizing', () {
    late List<MethodCall> calls;
    late List<AdaptiveBannerAd> banners;
    late FutureOr<Object?> Function(MethodCall) response;

    setUp(() {
      calls = [];
      banners = [];
      response = (call) =>
          call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize' ? 60 : const AdSize(width: 320, height: 90);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        (call) async {
          calls.add(call);
          if (call.method == 'loadBannerAd') {
            banners.add(instanceManager.adFor((call.arguments as Map)['adId'] as int) as AdaptiveBannerAd);
            return null;
          }
          if (call.method == 'disposeAd') return null;
          return response(call);
        },
      );
    });

    tearDown(() async {
      for (final banner in banners) {
        await banner.dispose();
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        null,
      );
    });

    testWidgets('anchored uses explicit orientation and SDK-selected height', (tester) async {
      final result = GoogleMobileAdsDriver().loadAd(_banner, bannerLayout: _wide);
      await tester.pump();
      expect(calls.first.arguments, {'orientation': 'landscape', 'width': 600});
      final ad = banners.single;
      expect(ad.size.width, 600);
      expect(ad.size.height, 60);
      ad.listener.onAdLoaded!(ad);
      expect(await result, same(ad));
      expect(ad.renderSize.value!.height, 60);
    });

    testWidgets('null SDK size fails without a guessed fixed banner request', (tester) async {
      response = (_) => null;
      final result = GoogleMobileAdsDriver().loadAd(_banner, bannerLayout: _narrow);
      await expectLater(result, throwsA(isA<LoadAdError>()));
      expect(banners, isEmpty);
    });

    testWidgets('disposal during SDK size resolution never starts a native load', (tester) async {
      final size = Completer<Object?>();
      response = (_) => size.future;
      final pool = EagerAdPool(driver: GoogleMobileAdsDriver(), mutex: PresentationMutex(), networkInfo: _Network());
      final pending = pool.preload(_banner, bannerLayout: _narrow);
      await tester.pump();
      pool.dispose();
      await pending;
      size.complete(60);
      await tester.pump();
      expect(banners, isEmpty);
    });

    testWidgets('consent is checked again after SDK size resolution', (tester) async {
      final size = Completer<Object?>();
      response = (_) => size.future;
      var allowed = true;
      final pool = EagerAdPool(driver: GoogleMobileAdsDriver(), mutex: PresentationMutex(), networkInfo: _Network(),
        canRequestAds: () => allowed);
      addTearDown(pool.dispose);
      final pending = pool.preload(_banner, bannerLayout: _narrow);
      await tester.pump();
      allowed = false;
      size.complete(60);
      await tester.pump();
      await pending;
      expect(banners, isEmpty);
    });

    testWidgets('inline waits for actual size and refresh never completes twice', (tester) async {
      const placement = BannerPlacement(
        androidId: 'test',
        iosId: 'test',
        sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
      );
      final size = Completer<Object?>();
      response = (_) => size.future;
      var settled = false;
      final result = GoogleMobileAdsDriver().loadAd(placement, bannerLayout: _narrow).then((ad) {
        settled = true;
        return ad;
      });
      await tester.pump();
      final ad = banners.single;
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      expect(settled, isFalse);
      size.complete(const AdSize(width: 320, height: 90));
      await tester.pump();
      expect(await result, same(ad));
      expect(ad.renderSize.value!.height, 90);
      response = (_) => const AdSize(width: 320, height: 120);
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      expect(ad.renderSize.value!.height, 120);
      ad.listener.onAdFailedToLoad!(ad, LoadAdError(3, 'test', 'refresh no fill', null));
      expect(ad.isDisposed, isFalse);
      expect(calls.where((call) => call.method == 'loadBannerAd'), hasLength(1));
    });

    testWidgets('disposed inline ignores late refresh size', (tester) async {
      const placement = BannerPlacement(
        androidId: 'test',
        iosId: 'test',
        sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
      );
      final result = GoogleMobileAdsDriver().loadAd(placement, bannerLayout: _narrow);
      await tester.pump();
      final ad = banners.single;
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      await result;
      final size = Completer<Object?>();
      response = (_) => size.future;
      ad.listener.onAdLoaded!(ad);
      await tester.pump();
      await ad.dispose();
      size.complete(const AdSize(width: 320, height: 120));
      await tester.pump();
      expect(ad.isDisposed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('platform load transport error settles rather than leaking a future', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        instanceManager.channel,
        (call) async {
          if (call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize') return 60;
          if (call.method == 'loadBannerAd') throw PlatformException(code: 'load_failed');
          return null;
        },
      );
      await expectLater(
        GoogleMobileAdsDriver().loadAd(_banner, bannerLayout: _narrow),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('Layout-aware engine', () {
    testWidgets('different widths never satisfy each other and new demand reloads loadOnce', (tester) async {
      final driver = _Driver();
      final pool = EagerAdPool(
        driver: driver,
        mutex: PresentationMutex(),
        networkInfo: _Network(),
        subsequentConcurrency: 2,
      );
      addTearDown(pool.dispose);
      final narrow = pool.leaseInlineAd(_banner, bannerLayout: _narrow);
      final wide = pool.leaseInlineAd(_banner, bannerLayout: _wide);
      await tester.pump();
      expect(driver.requests.map((request) => request.layout), [_narrow, _wide]);
      final first = Object();
      final second = Object();
      driver.requests[1].result.complete(second);
      await tester.pump();
      expect(await wide, same(second));
      expect(pool.isLoading(_banner, bannerLayout: _narrow), isTrue);
      driver.requests[0].result.complete(first);
      await tester.pump();
      expect(await narrow, same(first));
      await pool.preload(_banner, bannerLayout: _wide);
      expect(driver.requests, hasLength(2));
      final next = pool.leaseInlineAd(_banner, bannerLayout: _narrow);
      await tester.pump();
      expect(driver.requests, hasLength(3));
      driver.requests.last.result.complete(Object());
      await tester.pump();
      expect(await next, isNotNull);
    });

    testWidgets('shared buffer capacity evicts old layout rather than growing per width', (tester) async {
      final driver = _Driver();
      final pool = EagerAdPool(driver: driver, mutex: PresentationMutex(), networkInfo: _Network());
      addTearDown(pool.dispose);
      final first = pool.preload(_banner, bannerLayout: _narrow);
      await tester.pump();
      driver.requests.single.result.complete(Object());
      await first;
      final second = pool.preload(_banner, bannerLayout: _wide);
      await tester.pump();
      driver.requests.last.result.complete(Object());
      await second;
      expect(pool.isReady(_banner, bannerLayout: _wide), isTrue);
      expect(pool.isReady(_banner, bannerLayout: _narrow), isFalse);
    });

    test('registration does not request a banner without layout; request API rejects it', () {
      final driver = _Driver();
      final pool = EagerAdPool(driver: driver, mutex: PresentationMutex(), networkInfo: _Network());
      addTearDown(pool.dispose);
      pool.primeAll([_banner]);
      expect(driver.requests, isEmpty);
      expect(() => pool.preload(_banner), throwsArgumentError);
      expect(() => pool.isReady(_banner), throwsArgumentError);
    });

    test('same-ID incompatible sizing is rejected', () {
      final pool = EagerAdPool(driver: _Driver(), mutex: PresentationMutex(), networkInfo: _Network());
      addTearDown(pool.dispose);
      pool.validatePlacement(_banner);
      const conflicting = BannerPlacement(
        id: 'banner',
        androidId: 'test',
        iosId: 'test',
        loadOnce: true,
        sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
      );
      expect(() => pool.validatePlacement(conflicting), throwsArgumentError);
    });

    testWidgets('queue cancellation is isolated to the exact banner layout', (tester) async {
      final results = <BannerLayout?, Completer<dynamic>>{};
      final queue = TieredAdQueue(
        executor: (_, {bannerLayout, validateRequest}) => (results[bannerLayout] = Completer<dynamic>()).future,
        networkInfo: _Network(),
        subsequentConcurrency: 2,
      );
      addTearDown(queue.dispose);
      final narrow = queue.enqueue(_banner, bannerLayout: _narrow).catchError((_) => null);
      final wide = queue.enqueue(_banner, bannerLayout: _wide);
      await tester.pump();
      queue.cancel(_banner.id, bannerLayout: _narrow);
      expect(await narrow, isNull);
      expect(queue.pendingTaskCount(_banner.id, bannerLayout: _wide), 1);
      final ad = Object();
      results[_wide]!.complete(ad);
      results[_narrow]!.complete(Object());
      await tester.pump();
      expect(await wide, same(ad));
    });
  });

  testWidgets('unbounded banner width is an explicit layout error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AdBannerView(placement: _banner),
        ),
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });
}
