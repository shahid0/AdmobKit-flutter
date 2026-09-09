import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';

void main() {
  group('AdPlacement Hierarchy & Priority Inference Tests', () {
    test('Splash inline placement defaults to immediate priority', () {
      const banner = BannerPlacement(
        androidId: 'android_banner',
        iosId: 'ios_banner',
        isSplash: true,
      );

      expect(banner.isSplash, true);
      expect(banner.priority, AdPriority.immediate);
      expect(banner.format, AdFormat.banner);
      expect(banner.getUnitId(isAndroid: true), 'android_banner');
      expect(banner.getUnitId(isAndroid: false), 'ios_banner');
    });

    test('Splash fullscreen placement defaults to splashFullscreen priority', () {
      const interstitial = InterstitialPlacement(
        androidId: 'android_inter',
        iosId: 'ios_inter',
        isSplash: true,
        loadOnce: true,
      );

      expect(interstitial.isSplash, true);
      expect(interstitial.priority, AdPriority.splashFullscreen);
      expect(interstitial.loadOnce, true);
      expect(interstitial.format, AdFormat.interstitial);
    });

    test('Regular placements infer standard priorities and formats', () {
      const rewarded = RewardedPlacement(
        androidId: 'android_reward',
        iosId: 'ios_reward',
      );
      const appOpen = AppOpenPlacement(
        androidId: 'android_open',
        iosId: 'ios_open',
      );
      const native = NativePlacement(
        androidId: 'android_native',
        iosId: 'ios_native',
        factoryId: 'card_factory',
      );

      expect(rewarded.format, AdFormat.rewarded);
      expect(rewarded.priority, AdPriority.medium);
      expect(appOpen.format, AdFormat.appOpen);
      expect(appOpen.priority, AdPriority.high);
      expect(native.format, AdFormat.native);
      expect(native.factoryId, 'card_factory');
    });

    test('Native placement template constructors set correct factory IDs and properties', () {
      const big = NativePlacement.big(
        androidId: 'big_android',
        iosId: 'big_ios',
      );
      expect(big.factoryId, 'bigNativeAd');
      expect(big.template, NativeAdTemplate.big);
      expect(big.template?.defaultHeight, 300.0);
      expect(big.priority, AdPriority.medium);

      const medium = NativePlacement.medium(
        androidId: 'med_android',
        iosId: 'med_ios',
      );
      expect(medium.factoryId, 'listTileMedium');
      expect(medium.template, NativeAdTemplate.medium);
      expect(medium.template?.defaultHeight, 130.0);

      const small = NativePlacement.small(
        androidId: 'small_android',
        iosId: 'small_ios',
        isSplash: true,
      );
      expect(small.factoryId, 'smallNativeAd');
      expect(small.template, NativeAdTemplate.small);
      expect(small.template?.defaultHeight, 74.0);
      expect(small.priority, AdPriority.immediate);
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
