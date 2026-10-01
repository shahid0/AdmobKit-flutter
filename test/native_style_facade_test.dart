import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/infrastructure/appearance/native_appearance.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show instanceManager;

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;
  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  testWidgets('public style updates colors and radius on the same mounted SDK ad through generated transport', (
    tester,
  ) async {
    const placement = NativePlacement(
      template: NativeAdTemplate.rowWithLeadingIcon,
      id: 'feed',
      androidId: 'test',
      iosId: 'test',
      loadOnce: true,
      style: NativeAdStyle(headline: 0xff001122, callToActionCornerRadius: 8),
    );
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final manifests = <Map<Object?, Object?>>[];
    final channels = [
      for (final name in ['startSession', 'applyStyle', 'endSession'])
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.admob_kit_flutter.NativeAppearanceHost.$name',
          NativeAppearanceHost.pigeonChannelCodec,
        ),
    ];
    for (final channel in channels) {
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        if (channel.name.endsWith('applyStyle')) manifests.add((message! as List)[2] as Map<Object?, Object?>);
        return <Object?>[];
      });
    }
    final ads = <NativeAd>[];
    var disposals = 0;
    messenger.setMockMethodCallHandler(instanceManager.channel, (call) async {
      if (call.method == 'loadNativeAd') {
        ads.add(instanceManager.adFor((call.arguments as Map)['adId'] as int)! as NativeAd);
      }
      if (call.method == 'disposeAd') disposals++;
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (_) async => null);
    AdmobKit.networkInfoForTesting = _Network();
    addTearDown(() {
      AdmobKit.dispose();
      AdmobKit.networkInfoForTesting = null;
      messenger.setMockMethodCallHandler(instanceManager.channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockDecodedMessageHandler<Object?>(channel, null);
      }
    });
    await AdmobKit.initialize(
      config: const AdmobKitConfig(
        requestConsent: false,
        initializeNativeGma: false,
        logLevel: AdLogLevel.none,
        nativeStyle: NativeAdStyle(background: 0xff112233),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: AdNativeView(placement: placement)));
    await tester.pump();
    expect(ads, hasLength(1));
    final ad = ads.single;
    final render = ad.customOptions!['renderId'];
    NativeStyleData colors() => manifests.last[render]! as NativeStyleData;
    expect(colors().background, 0xff112233);
    expect(colors().headline, 0xff001122);
    expect(colors().callToActionCornerRadius, 8);
    await AdmobKit.setNativeStyle(const NativeAdStyle(background: 0xffabcdef));
    ad.listener.onAdLoaded!(ad);
    await tester.pump();
    await tester.pump();
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    await AdmobKit.setNativeStyle(
      const NativeAdStyle(callToActionText: 0xffffffff, callToActionCornerRadius: 0),
      placement: placement,
    );
    await tester.pump();
    expect(colors().background, 0xffabcdef);
    expect(colors().headline, isNull);
    expect(colors().callToActionText, 0xffffffff);
    expect(colors().callToActionCornerRadius, 0);
    await AdmobKit.setNativeStyle(const NativeAdStyle(callToActionCornerRadius: 6.5), placement: placement);
    expect(colors().callToActionCornerRadius, 6.5);
    await AdmobKit.setNativeStyle(const NativeAdStyle(), placement: placement);
    expect(colors().callToActionCornerRadius, isNull);
    expect(tester.widget<AdWidget>(find.byType(AdWidget)).ad, same(ad));
    expect(ads, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(disposals, 1);
    expect(manifests.last, isEmpty);
    AdmobKit.dispose();
    await tester.pump();
    await expectLater(AdmobKit.setNativeStyle(const NativeAdStyle()), throwsStateError);
  });
}
