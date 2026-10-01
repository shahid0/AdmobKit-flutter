import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/appearance/native_appearance.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

import 'package:flutter_ads_example/screens/ad_gallery_screen.dart';
import 'package:flutter_ads_example/screens/adaptive_banner_screen.dart';
import 'package:flutter_ads_example/screens/native_template_screen.dart';

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = [
    for (final name in ['startSession', 'applyStyle', 'endSession'])
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.admob_kit_flutter.NativeAppearanceHost.$name',
        NativeAppearanceHost.pigeonChannelCodec,
      ),
  ];
  late List<NativeAd> ads;
  late List<BannerAd> banners;
  late List<Map<Object?, Object?>> manifests;
  late bool failColors;

  Future<void> boot() async {
    ads = [];
    banners = [];
    manifests = [];
    failColors = false;
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        if (channel.name.endsWith('applyStyle')) {
          if (failColors) return <Object?>['test-error', 'Color transport failed', null];
          manifests.add((message! as List)[2] as Map<Object?, Object?>);
        }
        return <Object?>[];
      });
    }
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadNativeAd') {
        final ad = instanceManager.adFor((call.arguments as Map)['adId'] as int)! as NativeAd;
        ads.add(ad);
        ad.listener.onAdLoaded!(ad);
      }
      if (call.method == 'loadBannerAd') {
        final ad = instanceManager.adFor((call.arguments as Map)['adId'] as int)! as BannerAd;
        banners.add(ad);
        ad.listener.onAdLoaded!(ad);
      }
      if (call.method == 'AdSize#getLargeAnchoredAdaptiveBannerAdSize') return 60;
      if (call.method == 'AdSize#getAdSize') return const AdSize(width: 320, height: 90);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    AdmobKit.networkInfoForTesting = _Network();
    await AdmobKit.initialize(
      config: const AdmobKitConfig(requestConsent: false, initializeNativeGma: false, logLevel: AdLogLevel.none),
    );
  }

  tearDown(() async {
    AdmobKit.dispose();
    AdmobKit.networkInfoForTesting = null;
    // Let session cleanup reach the mocked transport before removing handlers.
    await Future<void>.value();
    messenger.setMockMethodCallHandler(instanceManager.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, null);
    }
  });

  testWidgets('browsing does not load the inventory; selecting loads only that template', (tester) async {
    await boot();
    await tester.pumpWidget(const MaterialApp(home: AdGalleryScreen()));
    expect(ads, isEmpty);
    expect(banners, isEmpty);
    await tester.tap(find.text('rowWithLeadingIcon'));
    await tester.pumpAndSettle();
    expect(ads, hasLength(1));
    expect(ads.single.factoryId, NativeAdTemplate.rowWithLeadingIcon.factoryId);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('fullscreenActionMiddle'), 400);
    expect(ads, hasLength(1));
    await tester.tap(find.text('fullscreenActionMiddle'));
    await tester.pumpAndSettle();
    expect(ads, hasLength(2));
    expect(AdmobKit.isShowingAd, isTrue);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(AdmobKit.isShowingAd, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every template fits a phone preview and rejects insufficient width before loading', (tester) async {
    await boot();
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final template in NativeAdTemplate.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: NativeTemplateScreen(key: ValueKey(template), template: template),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdWidget), findsOneWidget, reason: template.name);
      expect(tester.takeException(), isNull, reason: template.name);
    }
    expect(ads, hasLength(25));
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(const Size(300, 800));
    await tester.pumpWidget(const MaterialApp(home: NativeTemplateScreen(template: NativeAdTemplate.fullscreenMediaFirst)));
    await tester.pumpAndSettle();
    expect(find.textContaining('needs at least'), findsOneWidget);
    expect(ads, hasLength(25));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('live palette and reset keep the ad; transport errors are visible', (tester) async {
    await boot();
    await tester.pumpWidget(const MaterialApp(home: NativeTemplateScreen(template: NativeAdTemplate.rowWithLeadingIcon)));
    await tester.pumpAndSettle();
    final ad = ads.single;
    final renderId = ad.customOptions!['renderId'];
    Future<void> select(String label) async {
      await tester.tap(find.byTooltip('Apply native style'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await select('Midnight / gold');
    expect((manifests.last[renderId] as NativeStyleData).background, 0xff14213d);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    await select('Square CTA / inherited colors');
    expect((manifests.last[renderId] as NativeStyleData).callToActionCornerRadius, 0);
    await select('Rounded CTA / inherited colors');
    expect((manifests.last[renderId] as NativeStyleData).callToActionCornerRadius, 6.5);
    await select('Reset to inherited style');
    expect((manifests.last[renderId] as NativeStyleData).background, isNull);
    expect((manifests.last[renderId] as NativeStyleData).callToActionCornerRadius, isNull);
    failColors = true;
    await select('Forest / light');
    expect(find.textContaining('Style update failed:'), findsOneWidget);
    expect(ads, hasLength(1));
    failColors = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  for (final inline in [false, true]) {
    testWidgets('${inline ? 'inline' : 'anchored'} banner responds to available width', (tester) async {
      await boot();
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: AdaptiveBannerScreen(inline: inline)));
      await tester.pumpAndSettle();
      expect(banners, hasLength(1));
      expect(banners.last.size.width, 360);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(banners, hasLength(2));
      expect(banners.last.size.width, 312);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
