import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class SampleAds {
  static const splashBanner = BannerPlacement(
    id: 'splash_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    isSplash: false,
    priority: AdPriority.medium,
  );

  static const splashBigNative = NativePlacement(
    template: NativeAdTemplate.large1,
    id: 'splash_big_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    isSplash: true,
    loadOnce: true,
  );

  static const splashInterstitial = InterstitialPlacement(
    id: 'splash_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
    isSplash: true,
    loadOnce: true,
  );

  static const onboardingBigNative = NativePlacement(
    template: NativeAdTemplate.large1,
    id: 'onboarding_big_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    priority: AdPriority.immediate,
    loadOnce: true,
  );

  static const mainInterstitial = InterstitialPlacement(
    id: 'main_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );

  static const rewardedBonus = RewardedPlacement(
    id: 'rewarded_bonus',
    androidId: AdMobTestIds.rewardedAndroid,
    iosId: AdMobTestIds.rewardedIos,
  );

  static const rewardedInterstitial = RewardedInterstitialPlacement(
    id: 'rewarded_interstitial',
    androidId: AdMobTestIds.rewardedInterstitialAndroid,
    iosId: AdMobTestIds.rewardedInterstitialIos,
  );

  static const appOpen = AppOpenPlacement(
    id: 'app_open',
    androidId: AdMobTestIds.appOpenAndroid,
    iosId: AdMobTestIds.appOpenIos,
  );

  static const bigNative = NativePlacement(
    template: NativeAdTemplate.large1,
    id: 'native_big_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const mediumNative = NativePlacement(
    template: NativeAdTemplate.medium1,
    id: 'native_medium_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const smallNative = NativePlacement(
    template: NativeAdTemplate.small1,
    id: 'native_small_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const multiWidgetNative = NativePlacement(
    template: NativeAdTemplate.medium2,
    id: 'multi_widget_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const fullscreenNative = NativePlacement(
    template: NativeAdTemplate.fullscreen1,
    id: 'fullscreen_native_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const inlineAdaptiveBanner = BannerPlacement(
    id: 'inline_adaptive_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: BannerSizing.inlineAdaptive(maxHeight: 250),
  );

  static const anchoredAdaptiveBanner = BannerPlacement(
    id: 'anchored_adaptive_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: BannerSizing.anchoredAdaptive(),
  );

  static const allPlacements = [
    splashBigNative,
    splashBanner,
    splashInterstitial,
    onboardingBigNative,
    mainInterstitial,
    rewardedBonus,
    rewardedInterstitial,
    appOpen,
    bigNative,
    mediumNative,
    smallNative,
    multiWidgetNative,
    fullscreenNative,
    inlineAdaptiveBanner,
    anchoredAdaptiveBanner,
  ];
}
