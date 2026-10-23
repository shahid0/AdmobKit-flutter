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
    template: NativeAdTemplate.feedMediaFirst,
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
    template: NativeAdTemplate.feedMediaFirst,
    id: 'onboarding_big_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    priority: AdPriority.high,
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
    template: NativeAdTemplate.feedMediaFirst,
    id: 'native_big_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const mediumNative = NativePlacement(
    template: NativeAdTemplate.smartMedia,
    id: 'native_medium_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const smallNative = NativePlacement(
    template: NativeAdTemplate.rowWithLeadingIcon,
    id: 'native_small_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const multiWidgetNative = NativePlacement(
    template: NativeAdTemplate.splitMediaRight,
    id: 'multi_widget_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  // Fixed banners are preloaded by registerPlacements.
  static const standardBanner = BannerPlacement(
    id: 'gallery_standard_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: BannerSizing.standard(),
    loadOnce: true,
  );

  static const mrecBanner = BannerPlacement(
    id: 'gallery_mrec_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    sizing: BannerSizing.mrec(),
    loadOnce: true,
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
    standardBanner,
    mrecBanner,
  ];
}
