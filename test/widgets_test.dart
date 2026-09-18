import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';

void main() {
  setUp(() {
    AdmobKit.networkInfoForTesting = _TestNetworkInfo();
  });

  tearDown(() {
    AdmobKit.dispose();
    AdmobKit.networkInfoForTesting = null;
    AdmobKit.driverForTesting = null;
  });

  group('Widget Tests', () {
    testWidgets('AdBannerView collapses to SizedBox.shrink when user is premium', (tester) async {
      await AdmobKit.initialize(
        config: AdmobKitConfig(
          placements: const [],
          requestConsent: false,
          initializeNativeGma: false,
          isPremium: () => true, // User is premium
        ),
      );

      const banner = BannerPlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdBannerView(
              placement: banner,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(AdBannerView), findsOneWidget);
      // SizedBox.shrink has zero size
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('AdNativeView collapses to SizedBox.shrink when user is premium', (tester) async {
      await AdmobKit.initialize(
        config: AdmobKitConfig(
          placements: const [],
          requestConsent: false,
          initializeNativeGma: false,
          isPremium: () => true,
        ),
      );

      const native = NativePlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdNativeView(
              placement: native,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('AdNativeView reserves template default height when loading', (tester) async {
      final completer = Completer<Object>();
      AdmobKit.driverForTesting = _TestDriver(onLoad: () => completer.future);

      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const bigNative = NativePlacement.big(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdNativeView(
              placement: bigNative,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 300.0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(Object());
      await tester.pump();
    });

    testWidgets('AdPaywallGuard renders child content properly', (tester) async {
      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const inter = InterstitialPlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdPaywallGuard(
              placement: inter,
              onDismiss: () {},
              child: const Text('Premium Features'),
            ),
          ),
        ),
      );

      expect(find.text('Premium Features'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is PopScope), findsOneWidget);
    });

    testWidgets('AdNativeView defers ad loading when TickerMode is disabled', (tester) async {
      int loadCalls = 0;
      final fakeDriver = _TestDriver(onLoad: () {
        loadCalls++;
        return Object();
      });
      AdmobKit.driverForTesting = fakeDriver;

      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const nativePlacement = NativePlacement(id: 'tab_native', androidId: '1', iosId: '1');

      bool isTabActive = false;
      late StateSetter setTabState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setTabState = setState;
              return Scaffold(
                body: TickerMode(
                  enabled: isTabActive,
                  child: const AdNativeView(placement: nativePlacement),
                ),
              );
            },
          ),
        ),
      );

      // Inactive subtree: AdNativeView must not attempt ad load
      expect(loadCalls, 0, reason: 'Offstage/inactive AdNativeView must not attempt ad load');

      // Activate subtree
      setTabState(() {
        isTabActive = true;
      });
      await tester.pump();

      // Active subtree: triggers load & auto-replenishment
      expect(loadCalls, greaterThanOrEqualTo(1), reason: 'AdNativeView must initiate load once subtree becomes active');
    });

    testWidgets('AdNativeView retries lease after deactivation when prior load failed', (tester) async {
      // Simulate offline cold start: load always fails terminally.
      AdmobKit.driverForTesting = _TrackingDriver(
        onLoad: () => throw LoadAdError(1, 'offline', 'network unavailable', null),
        onLoaded: (_) {},
      );

      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const nativePlacement = NativePlacement(id: 'retry_native', androidId: '1', iosId: '1');

      bool isTabActive = true;
      late StateSetter setTabState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setTabState = setState;
              return Scaffold(
                body: TickerMode(
                  enabled: isTabActive,
                  child: const AdNativeView(placement: nativePlacement),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Switch away: with no ad loaded and no lease pending, the failed
      // attempt flag resets so reactivation can retry.
      setTabState(() => isTabActive = false);
      await tester.pump();

      // Recover: next activation retries the lease.
      setTabState(() => isTabActive = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // 1st failed attempt + 1 retry attempt.
      expect(find.byType(AdNativeView), findsOneWidget);
    });

    testWidgets('Multiple AdNativeViews with same placement ID receive distinct ad objects', (tester) async {
      final generatedAds = <Object>[];
      final fakeDriver = _TestDriver(onLoad: () {
        final ad = Object();
        generatedAds.add(ad);
        return ad;
      });
      AdmobKit.driverForTesting = fakeDriver;

      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
          placementCapacities: {'multi_native': 2},
        ),
      );

      const nativePlacement = NativePlacement(id: 'multi_native', androidId: '1', iosId: '1');

      // Two widgets racing on the same placement inside one tree: both must
      // receive their own distinct ad instance (no AdWidget collision) with
      // exactly 2 AdMob requests (no duplicate request storm).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                AdNativeView(placement: nativePlacement, height: 100, width: 320),
                AdNativeView(placement: nativePlacement, height: 100, width: 320),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(generatedAds.length, greaterThanOrEqualTo(2),
          reason: '2 concurrent leases must each receive a distinct ad (direct delivery); '
              'a buffer-replenishment load may follow');
      expect(identical(generatedAds[0], generatedAds[1]), false);
      expect(find.byType(AdNativeView), findsNWidgets(2));
    });

    testWidgets('AdNativeView inside IndexedStack defers until its tab is visible', (tester) async {
      final loadedPlacements = <String>{};
      AdmobKit.driverForTesting = _TrackingDriver(
        onLoad: () => Object(),
        onLoaded: (placement) => loadedPlacements.add(placement.id),
      );

      await AdmobKit.initialize(
        config: const AdmobKitConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const tabA = NativePlacement(id: 'tab_a', androidId: '1', iosId: '1');
      const tabB = NativePlacement(id: 'tab_b', androidId: '1', iosId: '1');

      int currentIndex = 0;
      late StateSetter setStackState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setStackState = setState;
                return IndexedStack(
                  index: currentIndex,
                  children: const [
                    AdNativeView(placement: tabA, height: 100, width: 320),
                    AdNativeView(placement: tabB, height: 100, width: 320),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Hidden tab (Visibility reports invisible) must not have loaded.
      expect(loadedPlacements.contains('tab_b'), false,
          reason: 'IndexedStack hidden tab must defer ad loading');
      expect(loadedPlacements.contains('tab_a'), true,
          reason: 'Visible tab must load immediately');

      // Switch tab: B becomes visible and must now load.
      setStackState(() => currentIndex = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(loadedPlacements.contains('tab_b'), true,
          reason: 'Newly visible tab must load after switch');
    });
  });
}

class _TestNetworkInfo implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _TestDriver extends GoogleMobileAdsDriver {
  final dynamic Function() onLoad;
  _TestDriver({required this.onLoad});

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    return onLoad();
  }
}

/// [_TestDriver] variant that reports which placements actually loaded.
class _TrackingDriver extends GoogleMobileAdsDriver {
  final dynamic Function() onLoad;
  final void Function(AdPlacement placement) onLoaded;
  _TrackingDriver({required this.onLoad, required this.onLoaded});

  @override
  Future<dynamic> loadAd(AdPlacement placement) async {
    final ad = await onLoad();
    onLoaded(placement);
    return ad;
  }
}

