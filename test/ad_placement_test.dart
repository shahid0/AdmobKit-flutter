import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

void main() {
  group('AdPlacement Hierarchy & Priority Inference Tests', () {
    test('Splash inline placement defaults to splash priority', () {
      const banner = BannerPlacement(androidId: 'android_banner', iosId: 'ios_banner', isSplash: true);

      expect(banner.isSplash, true);
      expect(banner.priority, AdPriority.splash);
      expect(banner.format, AdFormat.banner);
      expect(banner.getUnitId(isAndroid: true), 'android_banner');
      expect(banner.getUnitId(isAndroid: false), 'ios_banner');
    });

    test('Splash fullscreen placement defaults to splash priority', () {
      const interstitial = InterstitialPlacement(
        androidId: 'android_inter',
        iosId: 'ios_inter',
        isSplash: true,
        loadOnce: true,
      );

      expect(interstitial.isSplash, true);
      expect(interstitial.priority, AdPriority.splash);
      expect(interstitial.loadOnce, true);
      expect(interstitial.format, AdFormat.interstitial);
    });

    test('Regular placements infer standard priorities and formats', () {
      const rewarded = RewardedPlacement(androidId: 'android_reward', iosId: 'ios_reward');
      const appOpen = AppOpenPlacement(androidId: 'android_open', iosId: 'ios_open');
      const native = NativePlacement(
        androidId: 'android_native',
        iosId: 'ios_native',
        template: NativeAdTemplate.rowTextOnly,
      );

      expect(rewarded.format, AdFormat.rewarded);
      expect(rewarded.priority, AdPriority.medium);
      expect(appOpen.format, AdFormat.appOpen);
      expect(appOpen.priority, AdPriority.high);
      expect(native.format, AdFormat.native);
      expect(native.template.factoryId, 'admobKit.rowTextOnly');
    });

    test('Native placement template constructors set correct factory IDs and properties', () {
      const big = NativePlacement(template: NativeAdTemplate.feedMediaFirst, androidId: 'big_android', iosId: 'big_ios');
      expect(big.template.factoryId, 'admobKit.feedMediaFirst');
      expect(big.template, NativeAdTemplate.feedMediaFirst);
      expect(big.template.height, 340.0);
      expect(big.priority, AdPriority.medium);

      const medium = NativePlacement(template: NativeAdTemplate.splitMediaLeft, androidId: 'med_android', iosId: 'med_ios');
      expect(medium.template.factoryId, 'admobKit.splitMediaLeft');
      expect(medium.template, NativeAdTemplate.splitMediaLeft);
      expect(medium.template.height, 160.0);

      const small = NativePlacement(
        template: NativeAdTemplate.rowWithLeadingIcon,
        androidId: 'small_android',
        iosId: 'small_ios',
        isSplash: true,
      );
      expect(small.template.factoryId, 'admobKit.rowWithLeadingIcon');
      expect(small.template, NativeAdTemplate.rowWithLeadingIcon);
      expect(small.template.height, 104.0);
      expect(small.priority, AdPriority.splash);
    });

    test('Format getters distinguish fullscreen vs inline', () {
      expect(AdFormat.interstitial.isFullscreen, true);
      expect(AdFormat.rewarded.isFullscreen, true);
      expect(AdFormat.appOpen.isFullscreen, true);
      expect(AdFormat.banner.isFullscreen, false);
      expect(AdFormat.native.isFullscreen, false);

      expect(AdFormat.banner.isInline, true);
      expect(AdFormat.native.isInline, true);
      expect(AdFormat.interstitial.isInline, false);
    });
  });
}
