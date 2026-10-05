import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Orientation;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/models/ad_format.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/banner_layout.dart';
import 'adaptive_banner_ad.dart';
import 'managed_native_ad.dart';
import '../appearance/native_appearance.dart';
import '../../domain/models/ad_revenue_value.dart';
import '../logging/platform_ad_logger.dart';

/// Adapter wrapping the Google Mobile Ads (GMA) SDK.
class GoogleMobileAdsDriver {
  final PlatformAdLogger? _logger;
  final AdAnalyticsTracker? _analytics;
  final NativeAppearance? _appearance;

  GoogleMobileAdsDriver({PlatformAdLogger? logger, AdAnalyticsTracker? analytics, NativeAppearance? appearance})
    : _logger = logger,
      _appearance = appearance,
      _analytics = analytics;

  /// Initializes the GMA SDK with optional test device IDs.
  Future<InitializationStatus> initialize({List<String>? testDeviceIds}) async {
    _logger?.info('[GMA] Initializing Google Mobile Ads SDK...');
    final isMobile =
        !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    if (!isMobile) {
      _logger?.debug('[GMA] Non-mobile or test platform detected. Bypassing native GMA init.');
      return InitializationStatus(const {});
    }

    if (testDeviceIds != null && testDeviceIds.isNotEmpty) {
      final configuration = RequestConfiguration(testDeviceIds: testDeviceIds);
      await MobileAds.instance.updateRequestConfiguration(configuration);
      _logger?.debug('[GMA] Configured test devices: $testDeviceIds');
    }
    final status = await MobileAds.instance.initialize();
    _logger?.info('[GMA] Google Mobile Ads SDK initialized.');
    return status;
  }

  /// Loads an ad for the specified [placement].
  ///
  /// Resolves the unit ID based on current platform (Android vs iOS).
  /// Completes with the loaded ad instance, or throws [LoadAdError] on failure.
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) {
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
        if (bannerLayout == null) {
          throw ArgumentError('Banner requests require a BannerLayout.');
        }
        return _loadBanner(placement as BannerPlacement, bannerLayout, adUnitId, validateRequest);

      case AdFormat.native:
        return _loadNative(placement as NativePlacement, adUnitId, validateRequest);
    }
  }

  Future<NativeAd> _loadNative(NativePlacement placement, String adUnitId, void Function()? validateRequest) async {
    final renderId = await _appearance?.reserve(placement);
    const request = AdRequest();
    final completer = Completer<NativeAd>();
    completer.future.ignore();
    late final ManagedNativeAd nativeAd;
    nativeAd = ManagedNativeAd(
      adUnitId: adUnitId,
      factoryId: placement.template.factoryId,
      nativeAdOptions: NativeAdOptions(adChoicesPlacement: AdChoicesPlacement.topRightCorner),
      customOptions: renderId == null ? null : {'sessionId': _appearance!.sessionId, 'renderId': renderId},
      measureLayout: renderId == null ? null : (request) => _appearance!.layout(renderId, request),
      releaseAppearance: renderId == null
          ? null
          : () => _appearance!.release(renderId).catchError((Object error, StackTrace stack) {
              _logger?.error('[Native] Appearance release failed', error, stack);
            }),
      request: request,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          nativeAd.loadedAt = DateTime.now();
          completer.complete(nativeAd);
        },
        onAdFailedToLoad: (ad, error) {
          unawaited(
            nativeAd.dispose().catchError((Object error, StackTrace stack) {
              _logger?.error('[Native] Disposal failed', error, stack);
            }),
          );
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
    try {
      validateRequest?.call();
      await nativeAd.load();
    } catch (_) {
      await nativeAd.dispose();
      rethrow;
    }
    return completer.future;
  }

  Future<AdaptiveBannerAd> _loadBanner(
    BannerPlacement placement,
    BannerLayout layout,
    String unitId,
    void Function()? validateRequest,
  ) async {
    layout.validate();
    final maxHeight = placement.sizing.maxHeight;
    if (maxHeight != null && maxHeight < 32) {
      throw ArgumentError.value(maxHeight, 'maxHeight');
    }
    final AdSize? size = maxHeight != null
        ? AdSize.getInlineAdaptiveBannerAdSize(layout.width, maxHeight)
        : await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
            layout.orientation == BannerOrientation.portrait ? Orientation.portrait : Orientation.landscape,
            layout.width,
          );
    if (size == null || size.width <= 0 || (maxHeight == null && size.height <= 0)) {
      throw LoadAdError(1, 'admob_kit', 'SDK could not resolve adaptive banner size for $layout.', null);
    }
    validateRequest?.call();
    final loaded = Completer<AdaptiveBannerAd>();
    var revision = 0;
    late final AdaptiveBannerAd banner;
    void fail(Object error, [StackTrace? stack]) {
      if (loaded.isCompleted || banner.isDisposed) return;
      unawaited(banner.dispose());
      loaded.completeError(error, stack);
    }

    banner = AdaptiveBannerAd(
      adUnitId: unitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) async {
          final current = ++revision;
          try {
            final actual = maxHeight == null ? size : await banner.getPlatformAdSize();
            if (banner.isDisposed || current != revision) return;
            if (actual == null ||
                actual.width <= 0 ||
                actual.width > layout.width ||
                actual.height <= 0 ||
                (maxHeight != null && actual.height > maxHeight)) {
              throw LoadAdError(1, 'admob_kit', 'SDK returned an invalid adaptive banner render size.', null);
            }
            banner.loadedAt = DateTime.now();
            banner.renderSize.value = actual;
            if (!loaded.isCompleted) loaded.complete(banner);
          } catch (error, stack) {
            if (current != revision || banner.isDisposed) return;
            if (loaded.isCompleted) {
              _logger?.error('[Banner] Refresh size unavailable for "${placement.id}".', error, stack);
              banner.renderSize.value = null;
            } else {
              fail(error, stack);
            }
          }
        },
        onAdFailedToLoad: (_, error) {
          // A refresh failure must not complete the initial future twice or
          // destroy the already displayed creative. The SDK schedules refresh.
          if (loaded.isCompleted) {
            _logger?.warning('[Banner] Refresh failed for "${placement.id}": $error');
          } else {
            fail(error);
          }
        },
        onAdClicked: (_) => _analytics?.onAdClicked(placement),
        onPaidEvent: (_, micros, precision, currency) => _analytics?.onPaidEvent(
          placement,
          AdRevenueValue(micros: micros.toInt(), currencyCode: currency, precision: _mapPrecision(precision)),
        ),
      ),
    );
    // Observe platform transport errors as well as native load callbacks.
    unawaited(banner.load().catchError((Object error, StackTrace stack) => fail(error, stack)));
    return loaded.future;
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
        AdRevenueValue(micros: valueMicros.toInt(), currencyCode: currencyCode, precision: _mapPrecision(precision)),
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
