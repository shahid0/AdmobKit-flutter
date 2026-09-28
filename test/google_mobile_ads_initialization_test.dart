import 'dart:async';

import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// Native SDK codec is required to mock its actual initialization channel.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart' show AdMessageCodec;

void main() {
  final channel = MethodChannel('plugins.flutter.io/google_mobile_ads', StandardMethodCodec(AdMessageCodec()));

  testWidgets('SDK initialization waits for the native response beyond eight seconds', (tester) async {
    final sdk = Completer<InitializationStatus>();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) => sdk.future);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    var completed = false;
    final initialized = GoogleMobileAdsDriver().initialize().then((_) => completed = true);
    await tester.pump(const Duration(seconds: 9));
    expect(completed, isFalse);
    sdk.complete(InitializationStatus({}));
    await tester.pump();
    await initialized;
    expect(completed, isTrue);
  });

  testWidgets('native SDK errors propagate instead of becoming empty success', (tester) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'sdk_failed'));
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await expectLater(GoogleMobileAdsDriver().initialize(), throwsA(isA<PlatformException>()));
  });
}
