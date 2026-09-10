import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/models/ad_format.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_revenue_value.dart';
import '../logging/platform_ad_logger.dart';

/// Adapter wrapping the Google Mobile Ads (GMA) SDK.
class GoogleMobileAdsDriver {
  final PlatformAdLogger? _logger;
  final AdAnalyticsTracker? _analytics;

  GoogleMobileAdsDriver({
    PlatformAdLogger? logger,
    AdAnalyticsTracker? analytics,
  })  : _logger = logger,
        _analytics = analytics;

  /// Initializes the GMA SDK with optional test device IDs.
  Future<InitializationStatus> initialize({List<String>? testDeviceIds}) async {
    _logger?.info('[GMA] Initializing Google Mobile Ads SDK...');
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobile) {
      _logger?.debug('[GMA] Non-mobile or test platform detected. Bypassing native GMA init.');
      return InitializationStatus(const {});
    }

    if (testDeviceIds != null && testDeviceIds.isNotEmpty) {
      final configuration = RequestConfiguration(testDeviceIds: testDeviceIds);
      await MobileAds.instance.updateRequestConfiguration(configuration);
      _logger?.debug('[GMA] Configured test devices: $testDeviceIds');
    }
    try {
      final status = await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () => InitializationStatus(const {}),
      );
      _logger?.info('[GMA] Google Mobile Ads SDK initialized.');
      return status;
    } catch (e) {
      _logger?.warning('[GMA] MobileAds initialization fallback: $e');
      return InitializationStatus(const {});
    }
  }

  /// Loads an ad for the specified [placement].
  ///
  /// Resolves the unit ID based on current platform (Android vs iOS).
  /// Completes with the loaded ad instance, or throws [LoadAdError] on failure.
  Future<dynamic> loadAd(AdPlacement placement) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final adUnitId = placement.getUnitId(isAndroid: isAndroid);
    final request = const AdRequest();

    switch (placement.format) {
      case AdFormat.interstitial:
        final completer = Completer<InterstitialAd>();
        InterstitialAd.load(
          adUnitId: adUnitId,
          request: request,
          adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(ad),
            onAdFailedToLoad: (error) => completer.completeError(error),
          ),
        );
        return completer.future;

      case AdFormat.rewarded:
        final completer = Completer<RewardedAd>();
        RewardedAd.load(
          adUnitId: adUnitId,
          request: request,
          rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(ad),
            onAdFailedToLoad: (error) => completer.completeError(error),
          ),
        );
        return completer.future;

      case AdFormat.rewardedInterstitial:
        final completer = Completer<RewardedInterstitialAd>();
        RewardedInterstitialAd.load(
          adUnitId: adUnitId,
          request: request,
          rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(ad),
            onAdFailedToLoad: (error) => completer.completeError(error),
          ),
        );
        return completer.future;

      case AdFormat.appOpen:
        final completer = Completer<AppOpenAd>();
        AppOpenAd.load(
          adUnitId: adUnitId,
          request: request,
          adLoadCallback: AppOpenAdLoadCallback(
            onAdLoaded: (ad) => completer.complete(ad),
            onAdFailedToLoad: (error) => completer.completeError(error),
          ),
        );
        return completer.future;

      case AdFormat.banner:
        final completer = Completer<BannerAd>();
        late final BannerAd banner;
        banner = BannerAd(
          adUnitId: adUnitId,
          size: AdSize.banner,
          request: request,
          listener: BannerAdListener(
            onAdLoaded: (ad) => completer.complete(banner),
            onAdFailedToLoad: (ad, error) {
              banner.dispose();
              completer.completeError(error);
            },
            onAdClicked: (_) => _analytics?.onAdClicked(placement),
            onPaidEvent: (_, valueMicros, precision, currencyCode) {
              _analytics?.onPaidEvent(
                placement,
                AdRevenueValue(
                  micros: valueMicros.toInt(),
                  currencyCode: currencyCode,
                  precision: _mapPrecision(precision),
                ),
              );
            },
          ),
        );
        banner.load();
        return completer.future;

      case AdFormat.native:
        final completer = Completer<NativeAd>();
        final nativePlacement = placement as NativePlacement;
        late final NativeAd nativeAd;
        nativeAd = NativeAd(
          adUnitId: adUnitId,
          factoryId: nativePlacement.factoryId,
          request: request,
          listener: NativeAdListener(
            onAdLoaded: (ad) => completer.complete(nativeAd),
            onAdFailedToLoad: (ad, error) {
              nativeAd.dispose();
              completer.completeError(error);
            },
            onAdClicked: (_) => _analytics?.onAdClicked(placement),
            onPaidEvent: (_, valueMicros, precision, currencyCode) {
              _analytics?.onPaidEvent(
                placement,
                AdRevenueValue(
                  micros: valueMicros.toInt(),
                  currencyCode: currencyCode,
                  precision: _mapPrecision(precision),
                ),
              );
            },
          ),
        );
        nativeAd.load();
        return completer.future;
    }
  }

  /// Presents a loaded full-screen ad with unified lifecycle, analytics, and reward callbacks.
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required VoidCallback onDisplayed,
    required VoidCallback onDismissed,
    void Function(num rewardAmount, String rewardType)? onRewardGranted,
  }) {
    void handlePaidEvent(dynamic ad, double valueMicros, PrecisionType precision, String currencyCode) {
      _analytics?.onPaidEvent(
        placement,
        AdRevenueValue(
          micros: valueMicros.toInt(),
          currencyCode: currencyCode,
          precision: _mapPrecision(precision),
        ),
      );
    }

    FullScreenContentCallback<T> createCallback<T extends Ad>() {
      return FullScreenContentCallback<T>(
        onAdShowedFullScreenContent: (ad) {
          _logger?.info('[Show] Ad displayed on screen: ${placement.id}');
          _analytics?.onAdDisplayed(placement);
          onDisplayed();
        },
        onAdDismissedFullScreenContent: (ad) {
          _logger?.info('[Show] Ad dismissed by user: ${placement.id}');
          _analytics?.onAdDismissed(placement);
          onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _logger?.warning('[Show] Ad failed to display: [${error.code}] ${error.message}');
          onDismissed();
        },
        onAdClicked: (ad) {
          _logger?.debug('[Show] Ad clicked: ${placement.id}');
          _analytics?.onAdClicked(placement);
        },
      );
    }

    if (adInstance is InterstitialAd) {
      adInstance.onPaidEvent = handlePaidEvent;
      adInstance.fullScreenContentCallback = createCallback<InterstitialAd>();
      adInstance.show();
    } else if (adInstance is RewardedAd) {
      adInstance.onPaidEvent = handlePaidEvent;
      adInstance.fullScreenContentCallback = createCallback<RewardedAd>();
      adInstance.show(
        onUserEarnedReward: (ad, reward) {
          _logger?.info('[Reward] User earned reward: ${reward.amount} ${reward.type}');
          onRewardGranted?.call(reward.amount, reward.type);
        },
      );
    } else if (adInstance is RewardedInterstitialAd) {
      adInstance.onPaidEvent = handlePaidEvent;
      adInstance.fullScreenContentCallback = createCallback<RewardedInterstitialAd>();
      adInstance.show(
        onUserEarnedReward: (ad, reward) {
          _logger?.info('[Reward] User earned reward: ${reward.amount} ${reward.type}');
          onRewardGranted?.call(reward.amount, reward.type);
        },
      );
    } else if (adInstance is AppOpenAd) {
      adInstance.onPaidEvent = handlePaidEvent;
      adInstance.fullScreenContentCallback = createCallback<AppOpenAd>();
      adInstance.show();
    } else {
      _logger?.error('[Show] Unknown fullscreen ad instance type: ${adInstance.runtimeType}');
      onDismissed();
    }
  }

  static AdRevenuePrecision _mapPrecision(PrecisionType precision) {
    switch (precision) {
      case PrecisionType.unknown:
        return AdRevenuePrecision.unknown;
      case PrecisionType.estimated:
        return AdRevenuePrecision.estimated;
      case PrecisionType.publisherProvided:
        return AdRevenuePrecision.publisherProvided;
      case PrecisionType.precise:
        return AdRevenuePrecision.precise;
    }
  }
}
