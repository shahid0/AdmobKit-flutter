import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/engine/ad_engine.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/mutex/presentation_mutex.dart';

class _FakeNetworkInfo implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late List<int> disposedIds;

  setUp(() {
    calls = [];
    disposedIds = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      calls.add(call.method);
      if (call.method == 'disposeAd') {
        disposedIds.add((call.arguments as Map)['adId'] as int);
      }
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

  group('GoogleMobileAdsDriver: Direct showFullscreenAd cleanup', () {
    // 1. InterstitialAd: dismissal and show failure
    for (final failed in [false, true]) {
      testWidgets('InterstitialAd: fullscreen ${failed ? "show failure" : "dismissal"} disposes SDK ad exactly once and unregisters from registry', (tester) async {
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        int? id;
        messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'loadInterstitialAd') {
            id = (call.arguments as Map)['adId'] as int;
          } else if (call.method == 'disposeAd') {
            disposedIds.add((call.arguments as Map)['adId'] as int);
          }
          return null;
        });

        await InterstitialAd.load(
          adUnitId: 'test_interstitial',
          request: const AdRequest(),
          adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (_) {}, onAdFailedToLoad: (_) {}),
        );
        expect(id, isNotNull);
        final ad = instanceManager.adFor(id!) as InterstitialAd;
        ad.adLoadCallback.onAdLoaded(ad);

        var dismissed = 0;
        var displayed = 0;
        GoogleMobileAdsDriver().showFullscreenAd(
          placement: const InterstitialPlacement(id: 'interstitial_test', androidId: 'test', iosId: 'test'),
          adInstance: ad,
          onDisplayed: () => displayed++,
          onDismissed: () => dismissed++,
        );
        await tester.pump();

        if (failed) {
          ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(ad, AdError(0, 'test', 'simulated failure'));
        } else {
          ad.fullScreenContentCallback!.onAdShowedFullScreenContent!(ad);
          ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        }
        await tester.pump();

        expect(dismissed, 1);
        if (!failed) {
          expect(displayed, 1);
        }
        expect(calls.where((x) => x == 'disposeAd').length, 1);
        expect(disposedIds, [id]);
        expect(instanceManager.adFor(id!), isNull);
      });
    }

    // 2. RewardedAd: dismissal, show failure, and reward callback
    for (final failed in [false, true]) {
      testWidgets('RewardedAd: fullscreen ${failed ? "show failure" : "dismissal"} disposes SDK ad exactly once and unregisters from registry', (tester) async {
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        int? id;
        messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'loadRewardedAd') {
            id = (call.arguments as Map)['adId'] as int;
          } else if (call.method == 'disposeAd') {
            disposedIds.add((call.arguments as Map)['adId'] as int);
          }
          return null;
        });

        await RewardedAd.load(
          adUnitId: 'test_rewarded',
          request: const AdRequest(),
          rewardedAdLoadCallback: RewardedAdLoadCallback(onAdLoaded: (_) {}, onAdFailedToLoad: (_) {}),
        );
        expect(id, isNotNull);
        final ad = instanceManager.adFor(id!) as RewardedAd;
        ad.rewardedAdLoadCallback.onAdLoaded(ad);

        var dismissed = 0;
        var displayed = 0;
        num? rewardedAmount;
        String? rewardedType;

        GoogleMobileAdsDriver().showFullscreenAd(
          placement: const RewardedPlacement(id: 'rewarded_test', androidId: 'test', iosId: 'test'),
          adInstance: ad,
          onDisplayed: () => displayed++,
          onDismissed: () => dismissed++,
          onRewardGranted: (amount, type) {
            rewardedAmount = amount;
            rewardedType = type;
          },
        );
        await tester.pump();

        if (failed) {
          ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(ad, AdError(0, 'test', 'simulated error'));
        } else {
          ad.fullScreenContentCallback!.onAdShowedFullScreenContent!(ad);
          // Reward granted during presentation
          rewardedAmount = 10;
          rewardedType = 'coins';
          ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        }
        await tester.pump();

        expect(dismissed, 1);
        if (!failed) {
          expect(displayed, 1);
          expect(rewardedAmount, 10);
          expect(rewardedType, 'coins');
        }
        expect(calls.where((x) => x == 'disposeAd').length, 1);
        expect(disposedIds, [id]);
        expect(instanceManager.adFor(id!), isNull);
      });
    }

    // 3. RewardedInterstitialAd: dismissal and show failure
    for (final failed in [false, true]) {
      testWidgets('RewardedInterstitialAd: fullscreen ${failed ? "show failure" : "dismissal"} disposes SDK ad exactly once and unregisters from registry', (tester) async {
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        int? id;
        messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'loadRewardedInterstitialAd') {
            id = (call.arguments as Map)['adId'] as int;
          } else if (call.method == 'disposeAd') {
            disposedIds.add((call.arguments as Map)['adId'] as int);
          }
          return null;
        });

        await RewardedInterstitialAd.load(
          adUnitId: 'test_rewarded_interstitial',
          request: const AdRequest(),
          rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(onAdLoaded: (_) {}, onAdFailedToLoad: (_) {}),
        );
        expect(id, isNotNull);
        final ad = instanceManager.adFor(id!) as RewardedInterstitialAd;
        ad.rewardedInterstitialAdLoadCallback.onAdLoaded(ad);

        var dismissed = 0;
        GoogleMobileAdsDriver().showFullscreenAd(
          placement: const RewardedInterstitialPlacement(id: 'rewarded_interstitial_test', androidId: 'test', iosId: 'test'),
          adInstance: ad,
          onDisplayed: () {},
          onDismissed: () => dismissed++,
        );
        await tester.pump();

        if (failed) {
          ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(ad, AdError(0, 'test', 'simulated error'));
        } else {
          ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        }
        await tester.pump();

        expect(dismissed, 1);
        expect(calls.where((x) => x == 'disposeAd').length, 1);
        expect(disposedIds, [id]);
        expect(instanceManager.adFor(id!), isNull);
      });
    }

    // 4. AppOpenAd: dismissal and show failure
    for (final failed in [false, true]) {
      testWidgets('AppOpenAd: fullscreen ${failed ? "show failure" : "dismissal"} disposes SDK ad exactly once and unregisters from registry', (tester) async {
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        int? id;
        messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'loadAppOpenAd') {
            id = (call.arguments as Map)['adId'] as int;
          } else if (call.method == 'disposeAd') {
            disposedIds.add((call.arguments as Map)['adId'] as int);
          }
          return null;
        });

        await AppOpenAd.load(
          adUnitId: 'test_app_open',
          request: const AdRequest(),
          adLoadCallback: AppOpenAdLoadCallback(onAdLoaded: (_) {}, onAdFailedToLoad: (_) {}),
        );
        expect(id, isNotNull);
        final ad = instanceManager.adFor(id!) as AppOpenAd;
        ad.adLoadCallback.onAdLoaded(ad);

        var dismissed = 0;
        GoogleMobileAdsDriver().showFullscreenAd(
          placement: const AppOpenPlacement(id: 'app_open_test', androidId: 'test', iosId: 'test'),
          adInstance: ad,
          onDisplayed: () {},
          onDismissed: () => dismissed++,
        );
        await tester.pump();

        if (failed) {
          ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(ad, AdError(0, 'test', 'simulated error'));
        } else {
          ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
        }
        await tester.pump();

        expect(dismissed, 1);
        expect(calls.where((x) => x == 'disposeAd').length, 1);
        expect(disposedIds, [id]);
        expect(instanceManager.adFor(id!), isNull);
      });
    }

    // 5. Double terminal callback idempotency
    testWidgets('idempotent cleanup: multiple terminal callbacks invoke disposal and onDismissed exactly once', (tester) async {
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      int? id;
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call.method);
        if (call.method == 'loadInterstitialAd') {
          id = (call.arguments as Map)['adId'] as int;
        } else if (call.method == 'disposeAd') {
          disposedIds.add((call.arguments as Map)['adId'] as int);
        }
        return null;
      });

      await InterstitialAd.load(
        adUnitId: 'test_idempotent',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (_) {}, onAdFailedToLoad: (_) {}),
      );
      final ad = instanceManager.adFor(id!) as InterstitialAd;
      ad.adLoadCallback.onAdLoaded(ad);

      var dismissed = 0;
      GoogleMobileAdsDriver().showFullscreenAd(
        placement: const InterstitialPlacement(id: 'idempotent_test', androidId: 'test', iosId: 'test'),
        adInstance: ad,
        onDisplayed: () {},
        onDismissed: () => dismissed++,
      );
      await tester.pump();

      // Trigger dismissal AND failure simultaneously
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      ad.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(ad, AdError(0, 'test', 'extra error'));
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      await tester.pump();

      expect(dismissed, 1);
      expect(calls.where((x) => x == 'disposeAd').length, 1);
      expect(disposedIds, [id]);
      expect(instanceManager.adFor(id!), isNull);
    });
  });

  group('AdEngine: End-to-end fullscreen presentation lifecycle', () {
    testWidgets('recurring placement: normal dismissal disposes ad, releases mutex, and replenishes', (tester) async {
      final allocated = <int>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call.method);
        if (call.method == 'loadInterstitialAd') {
          allocated.add((call.arguments as Map)['adId'] as int);
        } else if (call.method == 'disposeAd') {
          disposedIds.add((call.arguments as Map)['adId'] as int);
        }
        return null;
      });

      final mutex = PresentationMutex();
      final pool = AdEngine(
        consumedLoadOnceIds: {},
        driver: GoogleMobileAdsDriver(),
        mutex: mutex,
        networkInfo: _FakeNetworkInfo(),
      );

      const placement = InterstitialPlacement(id: 'recurring_placement', androidId: 'test', iosId: 'test', loadOnce: false);

      // Preload the recurring placement
      final preloadFuture = pool.preload(placement);
      await tester.pump();

      expect(allocated.length, 1);
      final firstAd = instanceManager.adFor(allocated[0]) as InterstitialAd;
      firstAd.adLoadCallback.onAdLoaded(firstAd);
      await tester.pump();
      await preloadFuture;
      expect(pool.isReady(placement), true);

      // Present the ad
      var dismissedCount = 0;
      var displayedCount = 0;
      pool.show(
        placement,
        onDisplayed: () => displayedCount++,
        onDismissed: () => dismissedCount++,
      );
      await tester.pump();

      expect(mutex.isLocked, true);
      expect(pool.isReady(placement), false); // Removed from cache for presentation

      // Fire presentation displayed and dismissed
      firstAd.fullScreenContentCallback!.onAdShowedFullScreenContent!(firstAd);
      firstAd.fullScreenContentCallback!.onAdDismissedFullScreenContent!(firstAd);
      await tester.pump();

      // Assert: app continuation ran exactly once
      expect(dismissedCount, 1);
      expect(displayedCount, 1);

      // Assert: presentation lock released
      expect(mutex.isLocked, false);

      // Assert: first ad disposed exactly once and absent from SDK registry
      expect(disposedIds, contains(allocated[0]));
      expect(instanceManager.adFor(allocated[0]), isNull);

      // Assert: recurring placement initiates replenishment
      expect(allocated.length, 2);
      final secondAd = instanceManager.adFor(allocated[1]) as InterstitialAd;
      secondAd.adLoadCallback.onAdLoaded(secondAd);
      await tester.pump();

      pool.dispose();
      await tester.pump();
    });

    testWidgets('recurring placement: show failure disposes ad, releases mutex, and replenishes', (tester) async {
      final allocated = <int>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call.method);
        if (call.method == 'loadInterstitialAd') {
          allocated.add((call.arguments as Map)['adId'] as int);
        } else if (call.method == 'disposeAd') {
          disposedIds.add((call.arguments as Map)['adId'] as int);
        }
        return null;
      });

      final mutex = PresentationMutex();
      final pool = AdEngine(
        consumedLoadOnceIds: {},
        driver: GoogleMobileAdsDriver(),
        mutex: mutex,
        networkInfo: _FakeNetworkInfo(),
      );

      const placement = InterstitialPlacement(id: 'recurring_fail_placement', androidId: 'test', iosId: 'test', loadOnce: false);

      final preloadFuture = pool.preload(placement);
      await tester.pump();

      final firstAd = instanceManager.adFor(allocated[0]) as InterstitialAd;
      firstAd.adLoadCallback.onAdLoaded(firstAd);
      await tester.pump();
      await preloadFuture;

      var dismissedCount = 0;
      pool.show(
        placement,
        onDismissed: () => dismissedCount++,
      );
      await tester.pump();

      expect(mutex.isLocked, true);

      // Simulate failure to show
      firstAd.fullScreenContentCallback!.onAdFailedToShowFullScreenContent!(
        firstAd,
        AdError(0, 'test', 'presentation failed'),
      );
      await tester.pump();

      expect(dismissedCount, 1);
      expect(mutex.isLocked, false);
      expect(disposedIds, contains(allocated[0]));
      expect(instanceManager.adFor(allocated[0]), isNull);

      // Replenishment triggered for recurring placement
      expect(allocated.length, 2);
      final secondAd = instanceManager.adFor(allocated[1]) as InterstitialAd;
      secondAd.adLoadCallback.onAdLoaded(secondAd);
      await tester.pump();

      pool.dispose();
      await tester.pump();
    });

    testWidgets('loadOnce placement: dismissal disposes ad, releases mutex, and does NOT replenish', (tester) async {
      final allocated = <int>[];
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
        calls.add(call.method);
        if (call.method == 'loadInterstitialAd') {
          allocated.add((call.arguments as Map)['adId'] as int);
        } else if (call.method == 'disposeAd') {
          disposedIds.add((call.arguments as Map)['adId'] as int);
        }
        return null;
      });

      final mutex = PresentationMutex();
      final pool = AdEngine(
        consumedLoadOnceIds: {},
        driver: GoogleMobileAdsDriver(),
        mutex: mutex,
        networkInfo: _FakeNetworkInfo(),
      );

      const placement = InterstitialPlacement(id: 'load_once_placement', androidId: 'test', iosId: 'test', loadOnce: true);

      final preloadFuture = pool.preload(placement);
      await tester.pump();

      expect(allocated.length, 1);
      final ad = instanceManager.adFor(allocated[0]) as InterstitialAd;
      ad.adLoadCallback.onAdLoaded(ad);
      await tester.pump();
      await preloadFuture;

      var dismissedCount = 0;
      pool.show(
        placement,
        onDismissed: () => dismissedCount++,
      );
      await tester.pump();

      expect(mutex.isLocked, true);

      ad.fullScreenContentCallback!.onAdShowedFullScreenContent!(ad);
      ad.fullScreenContentCallback!.onAdDismissedFullScreenContent!(ad);
      await tester.pump();

      expect(dismissedCount, 1);
      expect(mutex.isLocked, false);
      expect(disposedIds, contains(allocated[0]));
      expect(instanceManager.adFor(allocated[0]), isNull);

      // Verify NO unwanted background replenishment for loadOnce
      expect(allocated.length, 1);
      expect(pool.isConsumed(placement), true);

      pool.dispose();
      await tester.pump();
    });
  });
}
