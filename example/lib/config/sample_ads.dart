import 'package:flutter_ads/flutter_ads.dart';

abstract final class SampleAds {
  // --- Splash Placements ---
  static const splashBanner = BannerPlacement(
    id: 'splash_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
    isSplash: false,
    priority: AdPriority.medium,
  );

  static const splashBigNative = NativePlacement.big(
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

  // --- Onboarding Placements ---
  static const onboardingBigNative = NativePlacement.big(
    id: 'onboarding_big_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    priority: AdPriority.immediate,
    loadOnce: true,
  );

  // --- Fullscreen Placements ---
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

  // --- Custom Native Ad Templates ---
  static const bigNative = NativePlacement.big(
    id: 'native_big_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const mediumNative = NativePlacement.medium(
    id: 'native_medium_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const smallNative = NativePlacement.small(
    id: 'native_small_showcase',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const allPlacements = [
    splashBigNative,
    splashBanner,
    splashInterstitial,
    onboardingBigNative,
    mainInterstitial,
    rewardedBonus,
    appOpen,
    bigNative,
    mediumNative,
    smallNative,
  ];
}
