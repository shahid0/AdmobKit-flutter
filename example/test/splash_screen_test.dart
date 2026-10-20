import 'dart:async';

import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/domain/ad_network.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ads_example/config/sample_ads.dart';
import 'package:flutter_ads_example/screens/onboarding_screen.dart';
import 'package:flutter_ads_example/screens/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

class _Driver extends GoogleMobileAdsDriver {
  final interstitial = Completer<Object>();
  int shows = 0;
  VoidCallback? dismiss;

  @override
  Future<dynamic> loadAd(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest}) async =>
      placement == SampleAds.splashInterstitial ? interstitial.future : null;

  @override
  void showFullscreenAd({
    required FullscreenPlacement placement,
    required dynamic adInstance,
    required VoidCallback onDisplayed,
    required VoidCallback onDismissed,
    void Function(num amount, String type)? onRewardGranted,
  }) {
    shows++;
    dismiss = onDismissed;
    onDisplayed();
  }
}

void main() {
  late _Driver driver;

  Future<void> initialize() async {
    driver = _Driver();
    await AdmobKitTestHarness.initialize(
      driver: driver,
      networkInfo: _Network(),
      initializeNativeGma: false,
      config: const AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none),
    );
  }

  tearDown(AdmobKit.dispose);

  testWidgets('splash waits for loading and continues only after dismissal', (tester) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(driver.shows, 0);
    expect(SplashScreen.isSplashActive, isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);

    driver.interstitial.complete(Object());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(driver.shows, 1);
    expect(find.byType(OnboardingScreen), findsNothing);

    driver.dismiss!();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(SplashScreen.isSplashActive, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('splash continues when settlement fails and show bypasses', (tester) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();
    driver.interstitial.completeError(LoadAdError(1, 'test', 'Invalid request', null));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(driver.shows, 0);
    expect(SplashScreen.isSplashActive, isFalse);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('disposing splash while waiting prevents presentation and navigation', (tester) async {
    await initialize();
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Replacement')));
    driver.interstitial.complete(Object());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(driver.shows, 0);
    expect(find.text('Replacement'), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
