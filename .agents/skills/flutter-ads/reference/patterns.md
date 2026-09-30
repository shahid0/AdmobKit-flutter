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

  static const onboardingNative = NativePlacement(
    template: NativeAdTemplate.large1,
    id: 'onboarding_native',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    priority: AdPriority.immediate,
    loadOnce: true,
  );

  static const feedNative = NativePlacement(
    template: NativeAdTemplate.medium1,
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

  final boot = AdmobKit.initialize(config: AdmobKitConfig(
    initialConcurrency: 1,
    subsequentConcurrency: 1,
    isPremium: () => UserStore.isVip,
  ));

  runApp(const MyApp());
  try {
    await boot;
  } catch (error, stack) {
    // Report startup failure; the app is already mounted and can continue without ads.
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
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
  final template = AppAds.feedNative.template;

  return Container(
    height: template.height, // 160 logical pixels; parent width must remain >=320
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: const AdNativeView(
      placement: AppAds.feedNative,
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
// Or gate the ad directly, especially in retained PageView children:
AdNativeView(placement: AppAds.onboardingNative, active: pageIndex == currentIndex)
```

## Fullscreen native and live colors

Declare a distinct `NativePlacement(template: NativeAdTemplate.fullscreen1, ...)`.
Mount in bounded space, with navigation outside the SDK assets:

```dart
Scaffold(
  appBar: AppBar(leading: const CloseButton()),
  body: SafeArea(child: AdNativeView(placement: AppAds.fullscreenNative)),
)

// In an async callback: updates the existing ad, without a new request.
await AdmobKit.setNativeStyle(
  const NativeAdStyle(background: 0xff14213d, headline: 0xffffffff,
    body: 0xffe5e5e5, callToActionBackground: 0xfffca311,
    callToActionText: 0xff14213d),
  placement: AppAds.fullscreenNative,
);
// Reset this placement to global/native defaults:
await AdmobKit.setNativeStyle(const NativeAdStyle(), placement: AppAds.fullscreenNative);
```

Catch errors around awaited color updates and check `mounted` before showing UI afterward.
Require at least 320 × 320 logical pixels for fullscreen hosts. Use `LayoutBuilder` to show non-ad content when the available space is insufficient. Loaded active fullscreen natives own the shared presentation lock; placeholders do not. No viewport inference: explicitly gate lazy/retained pages using the selected index.

## Adaptive banners

The default `BannerPlacement` uses anchored adaptive sizing. For in-content use, declare a separate placement with `sizing: BannerSizing.inlineAdaptive(maxHeight: 250)`.

```dart
// A bounded width is enough: do not impose a guessed height.
SafeArea(child: AdBannerView(placement: AppAds.bottomBanner))

// Only when explicitly preloading before the widget mounts:
final ready = await AdmobKit.waitFor(
  AppAds.bottomBanner,
  bannerLayout: const BannerLayout(width: 360, orientation: BannerOrientation.portrait),
);
// Use the actual future host width/orientation, not 360 as a universal value.
```

## App Open gating

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && appPolicyAllowsResumeAd && !AdmobKit.isShowingAd) {
    AdmobKit.show(AppAds.appOpen);
  }
}
```

`appPolicyAllowsResumeAd` is app-owned: exclude permission/consent interruptions, dialogs, paywalls and short background transitions. See the blueprint for dwell/cooldown handling.

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
