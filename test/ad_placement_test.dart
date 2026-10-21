import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

void main() {
  group('Collapsible banner placement', () {
    test('defaults to bottom anchored adaptive with regular banner policy', () {
      const placement = BannerPlacement.collapsible(androidId: 'android', iosId: 'ios');
      expect(placement.id, 'android');
      expect(placement.androidId, 'android');
      expect(placement.iosId, 'ios');
      expect(placement.format, AdFormat.banner);
      expect(placement.isCollapsible, isTrue);
      expect(placement.collapsible, CollapsibleAnchor.bottom);
      expect(placement.collapsible!.value, 'bottom');
      expect(placement.sizing, const BannerSizing.anchoredAdaptive());
      expect(placement.sizing.reserveSpace, isFalse);
      expect(placement.priority, AdPriority.medium);
      expect(placement.loadOnce, isFalse);
      expect(placement.isSplash, isFalse);
      expect(placement.validate, returnsNormally);
      const standard = BannerPlacement(androidId: 'android', iosId: 'ios');
      expect(standard.isCollapsible, isFalse);
      expect(standard.collapsible, isNull);
    });

    test('supports top anchor and explicit identity and loading policy', () {
      const placement = BannerPlacement.collapsible(
        id: 'header',
        androidId: 'android',
        iosId: 'ios',
        anchor: CollapsibleAnchor.top,
        priority: AdPriority.high,
        loadOnce: true,
      );
      expect(placement.id, 'header');
      expect(placement.collapsible!.value, 'top');
      expect(placement.priority, AdPriority.high);
      expect(placement.loadOnce, isTrue);
      expect(placement.validate, returnsNormally);
    });

    test('default constructor accepts a non-const anchored sizing value', () {
      final placement = BannerPlacement(
        androidId: 'android',
        iosId: 'ios',
        sizing: BannerSizing.anchoredAdaptive(),
        collapsible: CollapsibleAnchor.top,
      );
      expect(placement.validate, returnsNormally);
    });

    test('fixed and inline adaptive cannot request collapsible overlays', () {
      for (final sizing in const [
        BannerSizing.standard(),
        BannerSizing.mrec(),
        BannerSizing.large(),
        BannerSizing.leaderboard(),
        BannerSizing.fixed(width: 100, height: 100),
        BannerSizing.inlineAdaptive(maxHeight: 300),
      ]) {
        for (final anchor in CollapsibleAnchor.values) {
          expect(
            () => BannerPlacement(androidId: 'android', iosId: 'ios', sizing: sizing, collapsible: anchor),
            throwsAssertionError,
          );
        }
      }
    });

    test('equality and hashing include sizing and collapse anchor', () {
      const bottom = BannerPlacement.collapsible(androidId: 'android', iosId: 'ios');
      const same = BannerPlacement(androidId: 'android', iosId: 'ios', collapsible: CollapsibleAnchor.bottom);
      const top = BannerPlacement.collapsible(androidId: 'android', iosId: 'ios', anchor: CollapsibleAnchor.top);
      const standard = BannerPlacement(androidId: 'android', iosId: 'ios');
      const fixed = BannerPlacement(androidId: 'android', iosId: 'ios', sizing: BannerSizing.standard());
      expect(bottom, same);
      expect(same, bottom);
      expect(bottom.hashCode, same.hashCode);
      expect(bottom, isNot(top));
      expect(bottom, isNot(standard));
      expect(standard, isNot(fixed));
      expect(<BannerPlacement>{}..addAll([bottom, same, top, standard, fixed]), hasLength(4));
    });
  });

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
        template: NativeAdTemplate.cardContentTopTrailingIcon,
      );

      expect(rewarded.format, AdFormat.rewarded);
      expect(rewarded.priority, AdPriority.medium);
      expect(appOpen.format, AdFormat.appOpen);
      expect(appOpen.priority, AdPriority.high);
      expect(native.format, AdFormat.native);
      expect(native.template.factoryId, 'admobKit.cardContentTopTrailingIcon');
    });

    test('Native placement template constructors set correct factory IDs and properties', () {
      const big = NativePlacement(
        template: NativeAdTemplate.feedMediaFirst,
        androidId: 'big_android',
        iosId: 'big_ios',
      );
      expect(big.template.factoryId, 'admobKit.feedMediaFirst');
      expect(big.template, NativeAdTemplate.feedMediaFirst);
      expect(big.template.height, 340.0);
      expect(big.priority, AdPriority.medium);

      const medium = NativePlacement(
        template: NativeAdTemplate.cardContentTop,
        androidId: 'med_android',
        iosId: 'med_ios',
      );
      expect(medium.template.factoryId, 'admobKit.cardContentTop');
      expect(medium.template, NativeAdTemplate.cardContentTop);
      expect(medium.template.height, 132.0);

      const small = NativePlacement(
        template: NativeAdTemplate.cardActionTop,
        androidId: 'small_android',
        iosId: 'small_ios',
        isSplash: true,
      );
      expect(small.template.factoryId, 'admobKit.cardActionTop');
      expect(small.template, NativeAdTemplate.cardActionTop);
      expect(small.template.height, 132.0);
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
