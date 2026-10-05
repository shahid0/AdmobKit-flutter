import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
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
  Completer<InitializationStatus>? sdk;

  @override
  Future<InitializationStatus> initialize({List<String>? testDeviceIds}) =>
      sdk?.future ?? super.initialize(testDeviceIds: testDeviceIds);
  final requests = <Completer<dynamic>>[];
  final shown = <String>[];
  VoidCallback? dismiss;
  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
    final request = Completer<dynamic>();
    requests.add(request);
    return request.future;
  }

  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required VoidCallback onDisplayed,
    required VoidCallback onDismissed,
    void Function(num, String)? onRewardGranted,
  }) {
    shown.add(placement.id);
    dismiss = onDismissed;
    onDisplayed();
  }
}

void main() {
  late _Driver driver;
  late List<int> disposed;
  bool premium = false;
  NativePlacement placement(String id, {bool fullscreen = true}) => NativePlacement(
    id: id,
    androidId: 'test',
    iosId: 'test',
    loadOnce: true,
    template: fullscreen ? NativeAdTemplate.fullscreenMediaFirst : NativeAdTemplate.cardContentTop,
  );
  Widget adHost({String id = 'native', bool active = true, bool ticker = true, bool visible = true, Key? key}) =>
      TickerMode(
        enabled: ticker,
        child: Visibility(
          visible: visible,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: AdNativeView(key: key, placement: placement(id), active: active, showPlaceholder: false),
        ),
      );
  Widget page({bool active = true, bool ticker = true, bool visible = true}) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 320,
        height: 500,
        child: adHost(active: active, ticker: ticker, visible: visible),
      ),
    ),
  );

  Future<void> initialize(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    disposed = [];
    premium = false;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'disposeAd') disposed.add((call.arguments as Map)['adId'] as int);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    driver = _Driver();
    AdmobKit.driverForTesting = driver;
    AdmobKit.networkInfoForTesting = _Network();
    await AdmobKit.initialize(
      config: AdmobKitConfig(
        requestConsent: false,
        initializeNativeGma: false,
        logLevel: AdLogLevel.none,
        initialConcurrency: 2,
        subsequentConcurrency: 2,
        isPremium: () => premium,
      ),
    );
  }

  Future<ManagedNativeAd> completeLoad(WidgetTester tester, {int? index}) async {
    final ad = ManagedNativeAd(
      adUnitId: 'test',
      factoryId: NativeAdTemplate.fullscreenMediaFirst.factoryId,
      measureLayout: (request) async => request.height ?? 340,
      request: const AdRequest(),
      listener: NativeAdListener(),
    )..loadedAt = DateTime.now();
    await ad.load();
    driver.requests[index ?? driver.requests.length - 1].complete(ad);
    await tester.pump();
    await tester.pump();
    return ad;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    AdmobKit.dispose();
    await tester.pump();
  }

  tearDown(() {
    AdmobKit.dispose();
    AdmobKit.driverForTesting = null;
    AdmobKit.networkInfoForTesting = null;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets('loading is unlocked; a mounted native blocks interstitial and releases on removal', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(page());
    expect(AdmobKit.isShowingAd, isFalse);
    await completeLoad(tester);
    expect(AdmobKit.isShowingAd, isTrue);
    expect(find.byType(AdWidget), findsOneWidget);
    var skipped = 0;
    AdmobKit.show(
      const InterstitialPlacement(androidId: 'inter', iosId: 'inter'),
      onDismissed: () => skipped++,
    );
    expect(skipped, 1);
    expect(driver.shown, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(AdmobKit.isShowingAd, isFalse);
    expect(disposed, hasLength(1));
    await finish(tester);
  });

  testWidgets('SDK fullscreen owns display first; native waits then mounts after dismissal', (tester) async {
    await initialize(tester);
    const appOpen = AppOpenPlacement(androidId: 'open', iosId: 'open', loadOnce: true);
    final ready = AdmobKit.preload(appOpen);
    await tester.pump();
    driver.requests.single.complete(Object());
    await ready;
    AdmobKit.show(appOpen);
    expect(driver.shown, ['open']);
    await tester.pumpWidget(page());
    final ad = await completeLoad(tester);
    expect(find.byType(AdWidget), findsNothing);
    driver.dismiss!();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(AdmobKit.presentationMutex!.currentHolderId, 'native');
    driver.dismiss!(); // Late duplicate SDK callback must not release native ownership.
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  for (final gate in ['active', 'ticker', 'visibility']) {
    testWidgets('$gate releases ownership and restores the same fresh lease', (tester) async {
      await initialize(tester);
      await tester.pumpWidget(page());
      final ad = await completeLoad(tester);
      await tester.pumpWidget(page(active: gate != 'active', ticker: gate != 'ticker', visible: gate != 'visibility'));
      expect(AdmobKit.isShowingAd, isFalse);
      expect(find.byType(AdWidget), findsNothing);
      await tester.pumpWidget(page());
      await tester.pump();
      expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
      expect(AdmobKit.isShowingAd, isTrue);
      expect(driver.requests, hasLength(1));
      await finish(tester);
    });
  }

  testWidgets('inactive load completion never mounts or acquires until activated', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(page());
    await tester.pumpWidget(page(active: false));
    await completeLoad(tester);
    expect(AdmobKit.isShowingAd, isFalse);
    expect(find.byType(AdWidget), findsNothing);
    await tester.pumpWidget(page());
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  testWidgets('background releases ownership; expired retained ad reloads on resume', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(page());
    final ad = await completeLoad(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(AdmobKit.isShowingAd, isFalse);
    expect(find.byType(AdWidget), findsNothing);
    ad.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(disposed, hasLength(1));
    expect(AdmobKit.isShowingAd, isFalse);
    expect(driver.requests, hasLength(2));
    await completeLoad(tester);
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  testWidgets('two active hosts cannot display together; release hands over without reloading', (tester) async {
    await initialize(tester);
    Widget pair(bool firstActive) => MaterialApp(
      home: Row(
        children: [
          Expanded(
            child: adHost(id: 'first', active: firstActive),
          ),
          Expanded(child: adHost(id: 'second')),
        ],
      ),
    );
    await tester.pumpWidget(pair(true));
    await completeLoad(tester, index: 0);
    final second = await completeLoad(tester, index: 1);
    expect(find.byType(AdWidget), findsOneWidget);
    expect(AdmobKit.presentationMutex!.currentHolderId, 'first');
    await tester.pumpWidget(pair(false));
    await tester.pump();
    expect(find.byType(AdWidget), findsOneWidget);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(second));
    expect(AdmobKit.presentationMutex!.currentHolderId, 'second');
    expect(driver.requests, hasLength(2));
    await finish(tester);
  });

  testWidgets('expired ad waiting for another owner reloads instead of mounting stale', (tester) async {
    await initialize(tester);
    final mutex = AdmobKit.presentationMutex!;
    final other = mutex.tryAcquire('other')!;
    await tester.pumpWidget(page());
    final ad = await completeLoad(tester);
    ad.loadedAt = DateTime.now().subtract(const Duration(hours: 1));
    mutex.release(other);
    await tester.pump();
    expect(find.byType(AdWidget), findsNothing);
    expect(AdmobKit.isShowingAd, isFalse);
    expect(disposed, hasLength(1));
    expect(driver.requests, hasLength(2));
    await completeLoad(tester);
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  testWidgets('session replacement cannot be locked by an old pending native completion', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(page());
    final oldDriver = driver;
    final oldMutex = AdmobKit.presentationMutex!;
    AdmobKit.dispose();
    await initialize(tester);
    await tester.pump();
    final current = await completeLoad(tester);
    final late = ManagedNativeAd(
      adUnitId: 'test',
      factoryId: NativeAdTemplate.fullscreenMediaFirst.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(),
    );
    await late.load();
    oldDriver.requests.single.complete(late);
    await tester.pump();
    expect(oldMutex.tryAcquire('stale'), isNull);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(current));
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  testWidgets('unbounded fullscreen height fails before any load or ownership', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(MaterialApp(home: SingleChildScrollView(child: adHost())));
    expect(tester.takeException(), isA<FlutterError>());
    expect(driver.requests, isEmpty);
    expect(AdmobKit.isShowingAd, isFalse);
    await finish(tester);
  });

  testWidgets('covered routes release ownership and reuse the ad after popping', (tester) async {
    await initialize(tester);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: adHost()));
    final ad = await completeLoad(tester);
    unawaited(
      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Covered')))),
    );
    await tester.pumpAndSettle();
    expect(AdmobKit.isShowingAd, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(AdmobKit.isShowingAd, isTrue);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(driver.requests, hasLength(1));
    await finish(tester);
  });

  testWidgets('GlobalKey reparenting reacquires without duplicating SDK ownership', (tester) async {
    await initialize(tester);
    final key = GlobalKey();
    Widget movable(bool right) => MaterialApp(
      home: Row(
        children: [
          Expanded(child: right ? const SizedBox() : adHost(key: key)),
          Expanded(child: right ? adHost(key: key) : const SizedBox()),
        ],
      ),
    );
    await tester.pumpWidget(movable(false));
    final ad = await completeLoad(tester);
    await tester.pumpWidget(movable(true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(AdmobKit.isShowingAd, isTrue);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(driver.requests, hasLength(1));
    await finish(tester);
  });

  testWidgets('PageView active index prevents cached pages from holding the display', (tester) async {
    await initialize(tester);
    final controller = PageController();
    final current = ValueNotifier(0);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: current,
          builder: (_, index, _) => PageView(
            controller: controller,
            onPageChanged: (value) => current.value = value,
            children: [for (var i = 0; i < 3; i++) adHost(id: 'page$i', active: i == index)],
          ),
        ),
      ),
    );
    await completeLoad(tester);
    expect(AdmobKit.presentationMutex!.currentHolderId, 'page0');
    controller.jumpToPage(1);
    await tester.pump();
    await tester.pump();
    expect(AdmobKit.isShowingAd, isFalse, reason: 'New page is loading, old cached page cannot own display');
    expect(driver.requests, hasLength(2));
    await completeLoad(tester);
    expect(AdmobKit.presentationMutex!.currentHolderId, 'page1');
    await finish(tester);
    current.dispose();
    controller.dispose();
  });

  testWidgets('premium rebuild disposes visible native and releases ownership', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(page());
    await completeLoad(tester);
    premium = true;
    await tester.pumpWidget(page());
    expect(AdmobKit.isShowingAd, isFalse);
    expect(find.byType(AdWidget), findsNothing);
    expect(disposed, hasLength(1));
    await finish(tester);
  });

  testWidgets('failed load does not lock or leave the loading placeholder visible', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(MaterialApp(home: AdNativeView(placement: placement('failed'))));
    driver.requests.single.completeError(LoadAdError(1, 'test', 'invalid request', null));
    await tester.pump();
    expect(AdmobKit.isShowingAd, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await finish(tester);
  });

  testWidgets('ordinary inline templates never acquire the fullscreen lock', (tester) async {
    await initialize(tester);
    await tester.pumpWidget(MaterialApp(home: AdNativeView(placement: placement('inline', fullscreen: false))));
    await completeLoad(tester);
    expect(find.byType(AdWidget), findsOneWidget);
    expect(AdmobKit.isShowingAd, isFalse);
    await finish(tester);
  });

  testWidgets('host mounted after disposal is empty and starts demand when a new session is ready', (tester) async {
    await initialize(tester);
    AdmobKit.dispose();
    await tester.pumpWidget(MaterialApp(home: AdNativeView(placement: placement('restart'))));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(driver.requests, isEmpty);
    await initialize(tester);
    await tester.pump();
    expect(driver.requests, hasLength(1));
    await completeLoad(tester);
    expect(AdmobKit.isShowingAd, isTrue);
    await finish(tester);
  });

  testWidgets('initialization failure settles existing and newly mounted placeholders without requests', (
    tester,
  ) async {
    await initialize(tester);
    AdmobKit.dispose();
    driver.sdk = Completer<InitializationStatus>();
    final boot = AdmobKit.initialize(config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none));
    final failure = expectLater(boot, throwsStateError);
    await tester.pumpWidget(MaterialApp(home: AdNativeView(placement: placement('failure'))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(driver.requests, isEmpty);
    driver.sdk!.completeError(StateError('SDK initialization failed'));
    await failure;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: AdNativeView(placement: placement('after_failure'))));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(driver.requests, isEmpty);
    expect(AdmobKit.isShowingAd, isFalse);
    await finish(tester);
  });
}
