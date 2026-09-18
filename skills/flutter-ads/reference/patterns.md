# Integration Patterns

Full working code for the common integration shapes. Copy, rename `SampleAds` to your app's naming, swap `AdMobTestIds` for production unit IDs.

## Placements file

```dart
// lib/ads/app_ads.dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class AppAds {
  static const splashInterstitial = InterstitialPlacement(
    id: 'splash_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
    isSplash: true,
    loadOnce: true,
  );

  static const onboardingNative = NativePlacement.big(
    id: 'onboarding_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    priority: AdPriority.immediate,
    loadOnce: true,
  );

  static const feedNative = NativePlacement.medium(
    id: 'feed_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const bottomBanner = BannerPlacement(
    id: 'bottom_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
  );

  static const paywallExitInterstitial = InterstitialPlacement(
    id: 'paywall_exit_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );
}
```

## Two-stage boot

```dart
// main.dart — Stage 1: consent + SDK at cold boot
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdmobKit.initialize(config: const AdmobKitConfig(
    initialConcurrency: 1,
    subsequentConcurrency: 1,
    isPremium: () => UserStore.isVip,
  ));

  runApp(const MyApp());
}

// remote_config_service.dart — Stage 2: register when IDs resolve.
// The list mirrors what can actually be SHOWN on this install.
void onRemoteConfigLoaded({required bool isFirstLaunch}) {
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,   // shown every launch
    AppAds.feedNative,
    AppAds.bottomBanner,
    if (isFirstLaunch) AppAds.onboardingNative, // one-time screen → conditional
  ]);
}
```

## Deterministic splash

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  await Future.wait([
    FirebaseRemoteConfig.instance.fetchAndActivate(),
    AuthService.instance.restoreSession(),
    AdmobKit.waitFor(AppAds.splashInterstitial),
  ]);
  if (!context.mounted) return;

  AdmobKit.show(
    AppAds.splashInterstitial,
    onDismissed: () => Navigator.pushReplacementNamed(
        context, AuthService.instance.isLoggedIn ? '/home' : '/onboarding'),
  );
}
```

## Zero-CLS native card

```dart
Widget buildFeedNativeAd() {
  final template = NativeAdTemplate.medium;

  return Container(
    height: template.height, // 130dp — never guess
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: AdNativeView.templated(
      placement: AppAds.feedNative,
      template: template,
    ),
  );
}
```

## Paywall guard

```dart
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: triggerDismiss, // same exit flow as hardware back
      ),
    ),
    body: PaywallContent(),
  ),
)
```

## Ads in tabs

```dart
// IndexedStack: deferral works with zero extra code.
IndexedStack(
  index: currentIndex,
  children: const [TasksTab(), FocusTab(), AnalyticsTab()],
)

// TabBarView / PageView: gate each page explicitly.
TickerMode(enabled: currentIndex == 0, child: PageOne())
// or: Visibility(visible: currentIndex == 0, child: PageOne())
```

## App Open gating

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && !AdmobKit.isShowingAd) {
    AdmobKit.show(AppAds.appOpen);
  }
}
```

## Analytics tracker (revenue / funnels)

```dart
class FirebaseAdAnalytics implements AdAnalyticsTracker {
  @override
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue) {
    FirebaseAnalytics.instance.logAdImpression(
      adUnitName: placement.id,
      currencyCode: revenue.currencyCode,
      value: revenue.value, // micros / 1e6
    );
  }
  // onAdRequested / onAdLoaded / onAdFailedToLoad / onAdDisplayed /
  // onAdDismissed / onAdClicked → funnel events
}
```

## Diagnostics tracker (engineering health)

```dart
class SentryAdDiagnostics implements AdDiagnosticsTracker {
  @override
  void onDiagnosticReport(AdDiagnosticReport r) {
    if (r.eventType == AdDiagnosticEventType.blackHoleSuspected ||
        r.eventType == AdDiagnosticEventType.circuitBroken) {
      Sentry.captureMessage(
        'Ad engine: ${r.eventType.name} on ${r.placementId}',
        level: SentryLevel.warning,
      );
    }
  }
}
```

## GDPR consent testing & privacy settings

```dart
// Simulate EEA on test devices
await AdmobKit.initialize(config: AdmobKitConfig(
  requestConsent: true,
  consentTestConfig: ConsentTestConfig(
    debugGeography: DebugGeography.debugGeographyEea,
    testIdentifiers: ['YOUR_TEST_DEVICE_HASH'],
  ),
));

// Settings screen — GDPR requires an always-available privacy option
final updated = await AdmobKit.showPrivacyOptionsForm();
```
