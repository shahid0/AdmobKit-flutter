import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/adaptive_banner_ad.dart';
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';
import 'package:admob_kit_flutter/src/infrastructure/engine/ad_engine.dart';
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
  const fixedSizes = <String, (BannerSizing, AdSize)>{
    'standard': (BannerSizing.standard(), AdSize.banner),
    'medium rectangle': (
      BannerSizing.mediumRectangle(),
      AdSize.mediumRectangle,
    ),
    'MREC alias': (BannerSizing.mrec(), AdSize.mediumRectangle),
    'large': (BannerSizing.large(), AdSize.largeBanner),
    'large banner': (BannerSizing.largeBanner(), AdSize.largeBanner),
    'leaderboard': (BannerSizing.leaderboard(), AdSize.leaderboard),
    'custom': (BannerSizing.fixed(width: 468, height: 60), AdSize.fullBanner),
  };

  group('Banner sizing value', () {
    for (final entry in fixedSizes.entries) {
      test(entry.key, () {
        final (sizing, expected) = entry.value;
        expect(sizing.fixedWidth, expected.width);
        expect(sizing.fixedHeight, expected.height);
        expect(sizing.isFixed, isTrue);
        expect(sizing.isAdaptive, isFalse);
        expect(sizing.isInline, isFalse);
        expect(sizing.maxHeight, isNull);
        expect(sizing.reserveSpace, isTrue);
        expect(sizing.validate, returnsNormally);
        final custom = BannerSizing.fixed(
          width: expected.width,
          height: expected.height,
        );
        expect(sizing, custom);
        expect(sizing.hashCode, custom.hashCode);
      });
    }

    test('adaptive policies and reservation defaults', () {
      const anchored = BannerSizing.anchoredAdaptive();
      const inline = BannerSizing.inlineAdaptive(maxHeight: 160);
      expect(anchored.isAdaptive, isTrue);
      expect(anchored.isInline, isFalse);
      expect(anchored.reserveSpace, isFalse);
      expect(anchored.validate, returnsNormally);
      expect(inline.isAdaptive, isTrue);
      expect(inline.isInline, isTrue);
      expect(inline.reserveSpace, isTrue);
      expect(inline.fixedWidth, isNull);
      expect(inline.fixedHeight, isNull);
      expect(inline.validate, returnsNormally);
      expect(const BannerSizing.inlineAdaptive(maxHeight: 32).validate, returnsNormally);
      expect(const BannerSizing.fixed(width: 1, height: 1).validate, returnsNormally);
    });

    test('equality includes dimensions and reservation policy', () {
      expect(
        const BannerSizing.standard(),
        isNot(const BannerSizing.fixed(width: 321, height: 50)),
      );
      expect(
        const BannerSizing.standard(),
        isNot(const BannerSizing.largeBanner()),
      );
      expect(
        const BannerSizing.standard(),
        isNot(const BannerSizing.standard(reserveSpace: false)),
      );
      expect(
        const BannerSizing.inlineAdaptive(maxHeight: 160),
        isNot(
          const BannerSizing.inlineAdaptive(
            maxHeight: 160,
            reserveSpace: false,
          ),
        ),
      );
      expect(
        const BannerSizing.inlineAdaptive(maxHeight: 160),
        isNot(const BannerSizing.inlineAdaptive(maxHeight: 250)),
      );
      expect(
        const BannerSizing.mrec(reserveSpace: false),
        const BannerSizing.mediumRectangle(reserveSpace: false),
      );
      expect(const BannerSizing.large(reserveSpace: false), const BannerSizing.largeBanner(reserveSpace: false));
      expect(BannerSizing.anchoredAdaptive(), const BannerSizing.anchoredAdaptive());
    });

    test('every mobile preset supports opting out of reservation', () {
      for (final sizing in const [
        BannerSizing.standard(reserveSpace: false),
        BannerSizing.mrec(reserveSpace: false),
        BannerSizing.mediumRectangle(reserveSpace: false),
        BannerSizing.large(reserveSpace: false),
        BannerSizing.largeBanner(reserveSpace: false),
        BannerSizing.leaderboard(reserveSpace: false),
        BannerSizing.fixed(width: 120, height: 60, reserveSpace: false),
      ]) {
        expect(sizing.reserveSpace, isFalse);
        expect(sizing.validate, returnsNormally);
      }
    });

    test('descriptions identify mode, dimensions and reservation policy', () {
      expect(const BannerSizing.anchoredAdaptive().toString(), 'BannerSizing.anchoredAdaptive()');
      expect(
        const BannerSizing.inlineAdaptive(maxHeight: 160, reserveSpace: false).toString(),
        'BannerSizing.inlineAdaptive(maxHeight: 160, reserveSpace: false)',
      );
      expect(const BannerSizing.large().toString(), 'BannerSizing.fixed(width: 320, height: 100, reserveSpace: true)');
    });

    test('invalid dimensions are rejected', () {
      expect(
        () => BannerSizing.fixed(width: 0, height: 50),
        throwsAssertionError,
      );
      expect(
        () => BannerSizing.fixed(width: 320, height: -1),
        throwsAssertionError,
      );
      expect(
        () => BannerSizing.inlineAdaptive(maxHeight: 31),
        throwsAssertionError,
      );
    });
  });

  group('Banner SDK sizing', () {
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

    testWidgets('anchored requests the SDK slot and renders the creative height', (tester) async {
      response = (call) =>
          call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize' ? 120 : const AdSize(width: 600, height: 60);
      final result = GoogleMobileAdsDriver().loadAd(_banner, bannerLayout: _wide);
      await tester.pump();
      expect(calls.first.arguments, {'orientation': 'landscape', 'width': 600});
      final ad = banners.single;
      expect(ad.size.width, 600);
      expect(ad.size.height, 120);
      expect(ad.request.extras, isNull);
      ad.listener.onAdLoaded!(ad);
      expect(await result, same(ad));
      expect(ad.renderSize.value, const AdSize(width: 600, height: 60));
    });

    for (final anchor in CollapsibleAnchor.values) {
      testWidgets('collapsible ${anchor.name} requests extras and accepts expanded dimensions', (tester) async {
        final placement = BannerPlacement.collapsible(androidId: 'test', iosId: 'test', anchor: anchor);
        response = (call) =>
            call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize' ? 60 : const AdSize(width: 320, height: 350);
        final before = DateTime.now().millisecondsSinceEpoch;
        final result = GoogleMobileAdsDriver().loadAd(placement, bannerLayout: _narrow);
        await tester.pump();
        final ad = banners.single;
        expect(ad.request.extras!['collapsible'], anchor.value);
        expect(
          int.parse(ad.request.extras!['collapsible_request_id']!),
          inInclusiveRange(before, DateTime.now().millisecondsSinceEpoch),
        );
        expect(ad.size.height, 60);
        ad.listener.onAdLoaded!(ad);
        await tester.pump();
        expect(await result, same(ad));
        expect(ad.renderSize.value, const AdSize(width: 320, height: 350));
        expect(calls.map((call) => call.method), contains('getAdSize'));

        // A later SDK size update may report the collapsed creative dimensions.
        response = (_) => const AdSize(width: 320, height: 60);
        ad.listener.onAdLoaded!(ad);
        await tester.pump();
        expect(ad.renderSize.value, const AdSize(width: 320, height: 60));
        expect(ad.isDisposed, isFalse);
      });
    }

    for (final actual in <AdSize?>[
      null,
      const AdSize(width: 0, height: 300),
      const AdSize(width: 321, height: 300),
      const AdSize(width: 320, height: 0),
    ]) {
      testWidgets('collapsible rejects invalid platform dimensions $actual', (tester) async {
        const placement = BannerPlacement.collapsible(androidId: 'test', iosId: 'test');
        response = (call) => call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize' ? 60 : actual;
        final result = GoogleMobileAdsDriver().loadAd(placement, bannerLayout: _narrow);
        final failure = expectLater(result, throwsA(isA<LoadAdError>()));
        await tester.pump();
        final ad = banners.single;
        ad.listener.onAdLoaded!(ad);
        await tester.pump();
        await failure;
        expect(ad.isDisposed, isTrue);
      });
    }

    for (final entry in fixedSizes.entries) {
      testWidgets(
        '${entry.key} requests exact dimensions without adaptive calculation',
        (tester) async {
          final (sizing, expected) = entry.value;
          final placement = BannerPlacement(
            androidId: 'test',
            iosId: 'test',
            sizing: sizing,
          );
          response = (_) => expected;
          final result = GoogleMobileAdsDriver().loadAd(
            placement,
            bannerLayout: const BannerLayout(
              width: 800,
              orientation: BannerOrientation.portrait,
            ),
          );
          await tester.pump();
          expect(calls.map((call) => call.method), ['loadBannerAd']);
          final ad = banners.single;
          expect(ad.size, expected);
          ad.listener.onAdLoaded!(ad);
          await tester.pump();
          expect(await result, same(ad));
          expect(ad.renderSize.value, expected);
        },
      );
    }

    for (final actual in <AdSize?>[
      null,
      const AdSize(width: 300, height: 50),
      const AdSize(width: 320, height: 100),
    ]) {
      testWidgets('fixed size rejects mismatched platform size $actual', (
        tester,
      ) async {
        const placement = BannerPlacement(
          androidId: 'test',
          iosId: 'test',
          sizing: BannerSizing.standard(),
        );
        response = (_) => actual;
        final result = GoogleMobileAdsDriver().loadAd(
          placement,
          bannerLayout: _narrow,
        );
        final failure = expectLater(result, throwsA(isA<LoadAdError>()));
        await tester.pump();
        final ad = banners.single;
        ad.listener.onAdLoaded!(ad);
        await tester.pump();
        await failure;
        expect(ad.isDisposed, isTrue);
      });
    }

    testWidgets('null SDK size fails without a guessed fixed banner request', (tester) async {
      response = (_) => null;
      final result = GoogleMobileAdsDriver().loadAd(_banner, bannerLayout: _narrow);
      await expectLater(result, throwsA(isA<LoadAdError>()));
      expect(banners, isEmpty);
    });

    testWidgets('disposal during SDK size resolution never starts a native load', (tester) async {
      final size = Completer<Object?>();
      response = (_) => size.future;
      final pool = AdEngine(consumedLoadOnceIds: {}, driver: GoogleMobileAdsDriver(), mutex: PresentationMutex(), networkInfo: _Network());
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
      final pool = AdEngine(consumedLoadOnceIds: {}, driver: GoogleMobileAdsDriver(), mutex: PresentationMutex(), networkInfo: _Network(),
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
    testWidgets('cancelling a directly queued collapsible request clears its anchored state', (tester) async {
      const placement = BannerPlacement.collapsible(androidId: 'test', iosId: 'test');
      final result = Completer<dynamic>();
      final queue = AdEngine(
        executor: (_, {bannerLayout, validateRequest}) => result.future,
        networkInfo: _Network(),
      );
      addTearDown(queue.dispose);
      final pending = queue.enqueue(placement, bannerLayout: _narrow).catchError((_) => null);
      await tester.pump();
      queue.cancel(placement.id, bannerLayout: _narrow);
      expect(await pending, isNull);
      expect(queue.getState(placement, bannerLayout: _narrow), AdPlacementState.unloaded);
      result.complete(Object());
      await tester.pump();
    });

    test('request keys distinguish collapsible anchors from standard banners', () {
      AdRequestKey keyFor(CollapsibleAnchor? anchor) => AdLoadTask(
        placement: BannerPlacement(id: 'banner', androidId: 'test', iosId: 'test', collapsible: anchor),
        bannerLayout: _narrow,
        priority: AdPriority.medium,
      ).requestKey;
      final standard = keyFor(null);
      final top = keyFor(CollapsibleAnchor.top);
      final bottom = keyFor(CollapsibleAnchor.bottom);
      expect(standard.collapsible, isNull);
      expect(top.collapsible, CollapsibleAnchor.top);
      expect(bottom.collapsible, CollapsibleAnchor.bottom);
      expect(top.placementId, standard.placementId);
      expect(top.bannerLayout, standard.bannerLayout);
      expect({standard, top, bottom, keyFor(CollapsibleAnchor.bottom)}, hasLength(3));
    });

    testWidgets('collapsible preload state and cached lease use the same request key', (tester) async {
      const placement = BannerPlacement.collapsible(id: 'banner', androidId: 'test', iosId: 'test', loadOnce: true);
      final driver = _Driver();
      final pool = AdEngine(
        consumedLoadOnceIds: {},
        driver: driver,
        mutex: PresentationMutex(),
        networkInfo: _Network(),
      );
      addTearDown(pool.dispose);
      final states = <AdPlacementState>[];
      final statesById = <AdPlacementState>[];
      final subscription = pool.watchState(placement, bannerLayout: _narrow).listen(states.add);
      final byIdSubscription = pool.watchStateById(placement.id, bannerLayout: _narrow).listen(statesById.add);
      addTearDown(subscription.cancel);
      addTearDown(byIdSubscription.cancel);
      final pending = pool.preload(placement, bannerLayout: _narrow);
      await tester.pump();
      expect(pool.getStateById(placement.id, bannerLayout: _narrow), AdPlacementState.loading);
      final ad = Object();
      driver.requests.single.result.complete(ad);
      await pending;
      await tester.pump();
      expect(pool.isReady(placement, bannerLayout: _narrow), isTrue);
      expect(pool.getStateById(placement.id, bannerLayout: _narrow), AdPlacementState.ready);
      expect(await pool.leaseInlineAd(placement, bannerLayout: _narrow), same(ad));
      await tester.pump();
      expect(pool.getState(placement, bannerLayout: _narrow), AdPlacementState.unloaded);
      expect(states, [AdPlacementState.loading, AdPlacementState.ready, AdPlacementState.unloaded]);
      expect(statesById, states);
      expect(driver.requests, hasLength(1));
    });

    test('same-ID incompatible collapse anchor is rejected', () {
      final pool = AdEngine(
        consumedLoadOnceIds: {},
        driver: _Driver(),
        mutex: PresentationMutex(),
        networkInfo: _Network(),
      );
      addTearDown(pool.dispose);
      pool.validatePlacement(_banner);
      const conflicting = BannerPlacement.collapsible(id: 'banner', androidId: 'test', iosId: 'test', loadOnce: true);
      expect(() => pool.validatePlacement(conflicting), throwsArgumentError);
    });

    testWidgets('different widths never satisfy each other and new demand reloads loadOnce', (tester) async {
      final driver = _Driver();
      final pool = AdEngine(
        consumedLoadOnceIds: {},
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
      final pool = AdEngine(consumedLoadOnceIds: {}, driver: driver, mutex: PresentationMutex(), networkInfo: _Network());
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
      final pool = AdEngine(consumedLoadOnceIds: {}, driver: driver, mutex: PresentationMutex(), networkInfo: _Network());
      addTearDown(pool.dispose);
      pool.primeAll([_banner]);
      expect(driver.requests, isEmpty);
      expect(() => pool.preload(_banner), throwsArgumentError);
      expect(() => pool.isReady(_banner), throwsArgumentError);
    });

    test('same-ID incompatible sizing is rejected', () {
      final pool = AdEngine(consumedLoadOnceIds: {}, driver: _Driver(), mutex: PresentationMutex(), networkInfo: _Network());
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
      final queue = AdEngine(
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

  group('Banner host sizing', () {
    late _Driver driver;
    const placeholderKey = ValueKey('banner-placeholder');

    Widget host(
      BannerSizing sizing, {
      bool? reserveSpace,
      CollapsibleAnchor? collapsible,
      bool unbounded = false,
      double? width,
    }) {
      final view = AdBannerView(
        placement: BannerPlacement(
          id: 'host',
          androidId: 'test',
          iosId: 'test',
          sizing: sizing,
          collapsible: collapsible,
          loadOnce: true,
        ),
        width: width,
        reserveSpace: reserveSpace,
        placeholder: const ColoredBox(key: placeholderKey, color: Colors.grey),
      );
      return MaterialApp(
        home: Center(
          child: unbounded
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: view,
                )
              : SizedBox(width: 600, child: view),
        ),
      );
    }

    Future<AdaptiveBannerAd> completeAd(AdSize size) async {
      final ad = AdaptiveBannerAd(
        adUnitId: 'test',
        size: size,
        request: const AdRequest(),
        listener: const BannerAdListener(),
      );
      await ad.load();
      ad.loadedAt = DateTime.now();
      ad.renderSize.value = size;
      driver.requests.single.result.complete(ad);
      return ad;
    }

    Future<void> initialize() async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        instanceManager.channel,
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      driver = _Driver();
      await AdmobKitTestHarness.initialize(
        driver: driver,
        networkInfo: _Network(),
        initializeNativeGma: false,
        config: const AdmobKitConfig(
          requestConsent: false,
          logLevel: AdLogLevel.none,
        ),
      );
    }

    tearDown(() {
      AdmobKit.dispose();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(instanceManager.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });

    for (final fixed in [false, true]) {
      for (final policy in [false, true]) {
        for (final override in <bool?>[null, false, true]) {
          testWidgets(
            '${fixed ? 'fixed' : 'inline'} reserveSpace policy=$policy override=$override',
            (tester) async {
              await initialize();
              final sizing = fixed
                  ? BannerSizing.mrec(reserveSpace: policy)
                  : BannerSizing.inlineAdaptive(
                      maxHeight: 160,
                      reserveSpace: policy,
                    );
              final reserves = override ?? policy;
              final reservedHeight = fixed ? 250.0 : 160.0;
              final actualSize = fixed
                  ? AdSize.mediumRectangle
                  : const AdSize(width: 600, height: 90);
              await tester.pumpWidget(host(sizing, reserveSpace: override));
              expect(
                tester.getSize(find.byType(AdBannerView)).height,
                reserves ? reservedHeight : 0,
              );
              expect(
                find.byKey(placeholderKey),
                reserves ? findsOneWidget : findsNothing,
              );
              expect(
                driver.requests,
                hasLength(1),
                reason: 'Collapsed hosts still load',
              );
              await completeAd(actualSize);
              await tester.pump();
              await tester.pump();
              expect(
                tester.getSize(find.byType(AdBannerView)).height,
                reserves ? reservedHeight : actualSize.height.toDouble(),
              );
              expect(
                tester.getSize(find.byType(AdWidget)),
                Size(actualSize.width.toDouble(), actualSize.height.toDouble()),
              );
              expect(find.byKey(placeholderKey), findsNothing);
              expect(
                tester.getCenter(find.byType(AdWidget)).dx,
                tester.getCenter(find.byType(AdBannerView)).dx,
              );
              await tester.pumpWidget(const SizedBox());
            },
          );
        }
      }
    }

    testWidgets('collapsible height animates to updated native dimensions without reloading', (tester) async {
      await initialize();
      await tester.pumpWidget(host(const BannerSizing.anchoredAdaptive(), collapsible: CollapsibleAnchor.bottom));
      final ad = await completeAd(const AdSize(width: 600, height: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getSize(find.byType(AdBannerView)).height, 300);
      final adWidget = tester.widget<AdWidget>(find.byType(AdWidget));

      ad.renderSize.value = const AdSize(width: 600, height: 60);
      await tester.pump();
      expect(tester.getSize(find.byType(AdBannerView)).height, 300);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(find.byType(AdBannerView)).height, allOf(greaterThan(60), lessThan(300)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(find.byType(AdBannerView)).height, 60);
      expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(adWidget.ad));
      expect(driver.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(ad.isDisposed, isTrue);
    });

    testWidgets(
      'collapsed inline follows refreshed dimensions and missing size',
      (tester) async {
        await initialize();
        const sizing = BannerSizing.inlineAdaptive(
          maxHeight: 160,
          reserveSpace: false,
        );
        await tester.pumpWidget(host(sizing));
        final ad = await completeAd(const AdSize(width: 600, height: 90));
        await tester.pump();
        await tester.pump();
        ad.renderSize.value = const AdSize(width: 600, height: 120);
        await tester.pump();
        expect(tester.getSize(find.byType(AdBannerView)).height, 120);
        ad.renderSize.value = null;
        await tester.pump();
        expect(tester.getSize(find.byType(AdBannerView)).height, 0);
        expect(find.byType(AdWidget), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'fixed width defaults to configured width in an unbounded parent',
      (tester) async {
        await initialize();
        await tester.pumpWidget(
          host(const BannerSizing.mrec(), unbounded: true),
        );
        expect(tester.takeException(), isNull);
        expect(driver.requests.single.layout, isNull);
        expect(tester.getSize(find.byType(AdBannerView)), const Size(300, 250));
        await completeAd(AdSize.mediumRectangle);
        await tester.pump();
        await tester.pump();
        expect(tester.getSize(find.byType(AdWidget)), const Size(300, 250));
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('adaptive width can be explicit in an unbounded parent', (
      tester,
    ) async {
      await initialize();
      await tester.pumpWidget(
        host(
          const BannerSizing.anchoredAdaptive(),
          unbounded: true,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(driver.requests.single.layout!.width, 320);
      expect(tester.getSize(find.byType(AdBannerView)).height, 0);
      await completeAd(const AdSize(width: 320, height: 60));
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byType(AdBannerView)), const Size(320, 60));
      await tester.pumpWidget(const SizedBox());
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
