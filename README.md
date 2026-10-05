# AdmobKit for Flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg)](https://flutter.dev)
[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

**AdmobKit** is a Google Mobile Ads (AdMob) orchestration engine for Flutter with eager preloading, deterministic readiness, exclusive fullscreen presentation, 19 content-sized native compositions, and GDPR/UMP consent handling.

> **Package Import:**
> ```dart
> import 'package:admob_kit_flutter/admob_kit_flutter.dart';
> ```

---

## Why AdmobKit?

Standard `google_mobile_ads` implementations frequently suffer from blank flashes, layout shifts, multi-widget lifecycle crashes, and race conditions during screen transitions. AdmobKit provides structural architectural solutions:

| Problem in Standard AdMob | AdmobKit Solution |
| :--- | :--- |
| **Native Ad Sizing** | Native assets are measured before mounting. Loading estimates reserve initial space, but content-dependent heights can change it. |
| **`AdWidget already in tree` crash** | Demand-based instance leasing guarantees each widget receives an exclusively-owned ad object. |
| **Stuttered UI / Navigation Hangs** | **0ms Show Contract**: memory-cached ads render instantly; unready ads dismiss immediately with 0ms delay. |
| **Complex Native Android XML / iOS XIB** | 19 built-in native compositions rendered directly by native platforms with zero custom native code required. |
| **Splash Presentation Races** | Deterministic `waitFor(placement)` settlement composed with app startup tasks in `Future.wait`. |
| **GDPR / ATT Consent Boilerplate** | Automated two-stage initialization pipeline with built-in UMP consent collection. |

---

## Table of Contents

- [Quickstart](#quickstart)
- [Ad Formats & Code Examples](#ad-formats--code-examples)
  - [Native Ads & 19 Built-in Templates](#native-ads--19-built-in-templates)
  - [Fullscreen Native Ads](#fullscreen-native-ads)
  - [Adaptive Banners](#adaptive-banners)
  - [Interstitial & Splash Ads](#interstitial--splash-ads)
  - [Rewarded & Rewarded Interstitial Ads](#rewarded--rewarded-interstitial-ads)
  - [App Open Ads](#app-open-ads)
  - [Paywall Exit Interstitial Guard](#paywall-exit-interstitial-guard)
- [Advanced Features](#advanced-features)
  - [Dynamic Live Native Styling & Theming](#dynamic-live-native-styling--theming)
  - [GDPR UMP Consent & Testing](#gdpr-ump-consent--testing)
  - [VIP / Premium Ad Suppression](#vip--premium-ad-suppression)
  - [Tab & PageView Deferral](#tab--pageview-deferral)
- [API Reference](#api-reference)
- [Platform Setup](#platform-setup)
- [Observability (Analytics & Diagnostics)](#observability-analytics--diagnostics)
- [Comparison: Stock GMA vs AdmobKit](#comparison-stock-gma-vs-admobkit)

---

## Quickstart

### 1. Add Dependency

```bash
flutter pub add admob_kit_flutter
```

### 2. Declare Placements

Centralize ad definitions in a type-safe configuration:

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

  static const feedNative = NativePlacement(
    id: 'feed_native',
    template: NativeAdTemplate.cardContentTop,
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
  );

  static const bottomBanner = BannerPlacement(
    id: 'bottom_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
  );
}
```

### 3. Stage 1: Cold Boot in `main()`

Initialize consent and Google Mobile Ads SDK during startup:

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = AdmobKit.initialize(
    config: AdmobKitConfig(
      initialConcurrency: 1, // Single-radio queue discipline for fast startup
      subsequentConcurrency: 1,
      isPremium: () => UserStore.isVip, // Universal VIP suppression
    ),
  );

  runApp(const MyApp());

  try {
    await boot;
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}
```

### 4. Stage 2: Register Placements

Prime eager preloading when placement IDs are resolved (e.g., after Firebase Remote Config):

```dart
void onRemoteConfigLoaded({required bool isFirstLaunch}) {
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,
    AppAds.feedNative,
    AppAds.bottomBanner,
  ]);
}
```

### 5. Mount Widget or Show Ad

```dart
// Inline Banner or Native
const AdBannerView(placement: AppAds.bottomBanner);

// Fullscreen
AdmobKit.show(
  AppAds.splashInterstitial,
  onDismissed: () => Navigator.pushReplacementNamed(context, '/home'),
);
```

---

## Ad Formats & Code Examples

### Native Ads & 19 Built-in Templates

AdmobKit eliminates the need to author Android XML or iOS XIB files. Choose from **19 pre-built platform-rendered native templates** grouped by visual topology:

| Family | Loading estimate | Layout Topology | Canonical Preset |
| :--- | :--- | :--- | :--- |
| **Row** (3 variants) | **80 logical px** | `rowWithLeadingIcon`, `rowWithTrailingIcon`, `rowLeadingCta` | `NativeAdTemplate.compactRow` |
| **Smart Media / Medium** (2 variants) | **160 logical px** | `splitMediaLeft`, `splitMediaRight` | `NativeAdTemplate.smartMedia` |
| **Card** (3 variants) | **132 logical px** | `cardContentTop`, `cardActionTop`, `cardContentTopTrailingIcon` | `NativeAdTemplate.stackedCard` |
| **Feed Card** (6 variants) | **340 logical px** (280 side-CTA) | `feedMediaFirst`, `feedContentFirst`, `feedActionMiddle`, `feedTrailingIcon`, `feedMediaTopSideCta`, `feedContentTopSideCta` | `NativeAdTemplate.feedCard` |
| **Fullscreen** (5 variants) | **Bounded parent (min 320px)** | `fullscreenMediaFirst`, `fullscreenContentFirst`, `fullscreenActionMiddle`, `fullscreenTrailingIcon`, `fullscreenMediaSideCta` | `NativeAdTemplate.fullscreen` |

Names describe stable asset order, not creative content. All layouts retain a supplied icon. Cards omit non-video hero media; supplied video follows the identity (after the action in `cardActionTop`). Feed layouts size to content; fullscreen layouts fill bounded height. Compact row templates keep their CTA beside identity; supplied video appears above that row. Missing optional assets collapse, so two layouts may naturally look alike for an incomplete creative.

Use `rowWithLeadingIcon` for an icon/copy/action strip, `rowWithTrailingIcon` to place the icon after copy, or `rowLeadingCta` for a leading action. For media with a side action, choose `feedMediaTopSideCta` (media above the row), `feedContentTopSideCta` (row above media), or `fullscreenMediaSideCta` (bounded media above the row). `feedTrailingIcon` and `fullscreenTrailingIcon` place the icon after identity with a separate full-width action. Same-row buttons keep their position at every supported width: headline and CTA wrap and height grows; the button does not migrate below copy. Colors and CTA radius work on every layout.

Inline ads size themselves from the SDK assets, available width and Flutter text scale. The values above are initial loading estimates (`template.height`), not fixed heights. Provide bounded width of at least 320 logical pixels and let inline content grow; do not wrap it in a fixed-height container. Headline and CTA copy wrap when needed. Supplied body copy stays visible on one line using the platform text view's native end ellipsis. The SDK string is not manually shortened and its font is not shrunk; only missing or empty body assets collapse. Missing optional assets leave no empty slots. Supplied icons and video assets remain visible.

For a smaller media ad between list items, choose `smartMedia` (`splitMediaLeft`) or `splitMediaRight`. These keep a 120-logical-pixel-wide SDK media view beside the content column at every supported width. A compact 36-pixel icon sits beside headline/body; attribution and store metadata follow below, then the column-width CTA. Ordinary copy produces a shorter ad than a feed card; long copy and larger text can increase its measured height without turning it into a feed layout.

Mounting a content-sized native ad in a feed:

```dart
Widget buildNativeFeedItem() {
  return Container(
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

### Fullscreen Native Ads

Fullscreen native placements (`fullscreenMediaFirst` through `fullscreenActionMiddle`, or preset `NativeAdTemplate.fullscreen`) occupy the full bounded viewport with presentation lock ownership:

```dart
const fullscreenPlacement = NativePlacement(
  id: 'onboarding_fullscreen_native',
  template: NativeAdTemplate.fullscreen,
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  loadOnce: true,
);

// Host in a bounded container with app-level dismiss controls outside ad assets:
Scaffold(
  bottomNavigationBar: SafeArea(
    child: TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Continue'),
    ),
  ),
  body: const SafeArea(
    child: AdNativeView(placement: fullscreenPlacement),
  ),
);
```

Fullscreen hosts also need bounded height of at least 320 logical pixels and enough space for their actual copy, text scale and media. There is no built-in close button. Keep app navigation outside the ad assets. Only a measured, loaded, active fullscreen native owns the shared presentation lock; loading placeholders do not.

### Adaptive Banners

Banners support anchored adaptive sizing (fixed sticky banners) and inline adaptive sizing (in scrollable feeds):

```dart
// 1. Anchored Adaptive Banner (Standard sticky footer)
const AdBannerView(placement: AppAds.bottomBanner);

// 2. Inline Adaptive Banner (Scrollable list with maxHeight constraint)
const feedBanner = BannerPlacement(
  id: 'feed_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
);

const AdBannerView(placement: feedBanner);
```

### Interstitial & Splash Ads

AdmobKit introduces **deterministic settlement** with `waitFor`: never guess readiness with `Future.delayed` or arbitrary timers.

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  // Concurrently settle app bootstrapping and splash ad preloading
  await Future.wait([
    RemoteConfigService.instance.fetch(),
    AuthService.instance.restoreSession(),
    AdmobKit.waitFor(AppAds.splashInterstitial),
  ]);

  if (!context.mounted) return;

  // Show ad if ready; onDismissed fires immediately if unready or offline (0ms delay)
  AdmobKit.show(
    AppAds.splashInterstitial,
    onDismissed: () => Navigator.pushReplacementNamed(context, '/home'),
  );
}
```

### Rewarded & Rewarded Interstitial Ads

Safely award rewards only when the user earns them:

```dart
AdmobKit.show(
  AppAds.rewardedBooster,
  onRewardGranted: (num amount, String type) {
    userStore.addCredits(amount.toInt());
  },
  onDismissed: () {
    // Refresh UI after ad dismissal
    setState(() {});
  },
);
```

### App Open Ads

Prevent App Open ads from firing unexpectedly over consent dialogs, paywalls, or active fullscreen ads:

```dart
class AppLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !AdmobKit.isShowingAd) {
      AdmobKit.show(AppAds.appOpen);
    }
  }
}
```

### Paywall Exit Interstitial Guard

`AdPaywallGuard` captures both the visual close button **and** the Android hardware back button / iOS predictive back swipe:

```dart
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: triggerDismiss, // Triggers exit ad then onDismiss
      ),
    ),
    body: const PaywallContent(),
  ),
);
```

---

## Advanced Features

### Dynamic Live Native Styling & Theming

Theme all 19 native templates with `NativeAdStyle`. Changes apply immediately to pending, cached, and rendered ads without reloading:

```dart
// 1. Initial Style on Placement
const feedNative = NativePlacement(
  id: 'feed_native',
  template: NativeAdTemplate.cardContentTop,
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  style: NativeAdStyle(
    callToActionBackground: 0xFF2563EB,
    callToActionText: 0xFFFFFFFF,
    callToActionCornerRadius: 8, // Square = 0, Rounded = 6-8, Pill = 24+
  ),
);

// 2. Dynamic Runtime Theme Switch (e.g. Dark Mode)
await AdmobKit.setNativeStyle(
  const NativeAdStyle(
    background: 0xFF1E293B,
    headline: 0xFFF8FAFC,
    body: 0xFF94A3B8,
    callToActionBackground: 0xFF3B82F6,
    callToActionText: 0xFFFFFFFF,
    callToActionCornerRadius: 100, // Pill button
  ),
);

// 3. Reset placement back to global default
await AdmobKit.setNativeStyle(const NativeAdStyle(), placement: feedNative);
```

### GDPR UMP Consent & Testing

AdmobKit automatically invokes Google User Messaging Platform (UMP) on boot when `requestConsent: true`. Test European Economic Area (EEA) consent flows locally without a VPN:

```dart
await AdmobKit.initialize(
  config: AdmobKitConfig(
    requestConsent: true,
    consentTestConfig: ConsentTestConfig(
      debugGeography: DebugGeography.debugGeographyEea,
      testIdentifiers: ['YOUR_TEST_DEVICE_HASH_ID'],
    ),
  ),
);

// Present privacy options form from Settings screen
final updated = await AdmobKit.showPrivacyOptionsForm();
```

### VIP / Premium Ad Suppression

Define a single callback during initialization:

```dart
await AdmobKit.initialize(
  config: AdmobKitConfig(
    isPremium: () => UserStore.isVip,
  ),
);
```

When `isPremium` returns `true`:
- Background preloading queues are suspended.
- Inline ad widgets (`AdBannerView`, `AdNativeView`) collapse into `SizedBox.shrink`.
- `AdmobKit.show(...)` immediately fires `onDismissed` (0ms delay).
- `AdPaywallGuard` bypasses ads and executes dismiss immediately.

### Tab & PageView Deferral

Ad widgets automatically defer network requests when mounted inside hidden tabs:
- **`IndexedStack`**: Ad loads trigger only when the tab becomes active.
- **`PageView` / `TabBarView`**: Pass the `active:` parameter or wrap in `TickerMode`:

```dart
AdNativeView(
  placement: AppAds.onboardingNative,
  active: pageIndex == currentPage,
);
```

---

## API Reference

### `AdmobKit` Facade

| Method | Return Type | Description |
| :--- | :--- | :--- |
| `initialize({AdmobKitConfig config})` | `Future<void>` | Boots UMP consent and initializes GMA SDK. |
| `registerPlacements(Iterable<AdPlacement>)` | `void` | Registers placements and initiates eager preloading pool. |
| `show(FullscreenPlacement, ...)` | `void` | Displays fullscreen ad with 0ms non-blocking guarantee. |
| `waitFor(AdPlacement, {Duration? timeout})` | `Future<bool>` | Awaits ad settlement deterministically. |
| `setNativeStyle(NativeAdStyle, {placement})` | `Future<void>` | Dynamically updates appearance across cached and live native ads. |
| `isReady(AdPlacement)` | `bool` | Checks if a placement currently has an ad ready in memory. |
| `canRequestAds` | `bool` | Synchronous snapshot of consent, SDK, and non-premium readiness. |
| `waitUntilCanRequestAds()` | `Future<bool>` | Awaits resolution of pending consent or SDK initialization. |
| `showPrivacyOptionsForm()` | `Future<bool>` | Opens GDPR privacy form (Settings screen integration). |
| `openAdInspector()` | `void` | Opens AdMob native Ad Inspector overlay for QA testing. |
| `isShowingAd` | `bool` | Returns `true` if any fullscreen ad is currently on screen. |
| `dispose()` | `void` | Tears down pool, queues, and mutex locks (testing & hot restart). |

### `AdmobKitConfig`

| Field | Default | Description |
| :--- | :--- | :--- |
| `isPremium` | `null` | Universal suppression gate callback (`bool Function()?`). |
| `requestConsent` | `true` | Executes Google UMP consent and ATT pipelines. |
| `nativeStyle` | `null` | Global default `NativeAdStyle` for all native templates. |
| `initialConcurrency` | `1` | Startup queue concurrency limit (prevents network contention). |
| `subsequentConcurrency` | `1` | Post-startup queue concurrency limit. |
| `adTtl` | `50 min` | In-memory cache freshness duration before eviction. |
| `analytics` | `null` | `AdAnalyticsTracker` implementation for ILRD and funnels. |
| `diagnostics` | `null` | `AdDiagnosticsTracker` implementation for Sentry/Crashlytics. |
| `logLevel` | `AdLogLevel.info` | Logging verbosity (`verbose`, `info`, `warning`, `error`, `none`). |

---

## Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<application ...>
    <!-- AdMob Application ID (Swap for your production ID) -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713"/>

    <!-- Recommended Google Mobile Ads startup flags -->
    <meta-data android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION" android:value="true"/>
    <meta-data android:name="com.google.android.gms.ads.flag.OPTIMIZE_AT_STARTUP" android:value="true"/>
</application>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>

<key>NSUserTrackingUsageDescription</key>
<string>This identifier helps us deliver personalized advertising to you.</string>

<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

> **Testing Unit IDs:** Pre-configured Google test IDs are accessible via `AdMobTestIds.*` (e.g. `AdMobTestIds.bannerAndroid`, `AdMobTestIds.interstitialIos`).

---

## Observability (Analytics & Diagnostics)

Wire marketing revenue funnels and engineering health monitoring independently:

```dart
AdmobKit.initialize(
  config: AdmobKitConfig(
    analytics: FirebaseAnalyticsTracker(),   // LTV & Impression-Level Revenue (ILRD)
    diagnostics: SentryDiagnosticsTracker(), // Timeout & circuit breaker alerts
    logLevel: kReleaseMode ? AdLogLevel.none : AdLogLevel.info,
  ),
);
```

### Impression-Level Revenue Data (ILRD)

`AdAnalyticsTracker.onPaidEvent` delivers precise impression revenue metrics:

```dart
class FirebaseAnalyticsTracker implements AdAnalyticsTracker {
  @override
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue) {
    FirebaseAnalytics.instance.logAdImpression(
      adUnitName: placement.id,
      currencyCode: revenue.currencyCode,
      value: revenue.value, // micros / 1e6
    );
  }
}
```

---

## Comparison: Stock GMA vs AdmobKit

| Feature | `google_mobile_ads` | `admob_kit_flutter` |
| :--- | :--- | :--- |
| **Native Ad Layouts** | Requires custom Android XML & iOS XIB files | **19 Built-in platform templates** (Zero XML/XIB needed) |
| **Dynamic Styling** | Static compile-time files | **Live runtime theming** via Pigeon (`setNativeStyle`) |
| **CTA Button Radius** | Fixed native drawable | **Configurable radius** (Square, rounded, or pill) |
| **Native Layout Sizing** | App-managed dimensions | Native measurement from assets, host width, and text scale |
| **Multiple Same-Ad Widgets** | Fatal `AdWidget already in tree` crash | **Exclusive instance leasing** (Crash-free) |
| **Splash Display** | Guesswork with `Future.delayed` | **Deterministic settlement** with `waitFor` |
| **VIP / Premium Gate** | Manual checks across every screen | **Single `isPremium` callback** enforced globally |
| **Concurrency / Lock** | Ad collisions during transitions | **Token-based Presentation Mutex** |
| **Tabbed Containers** | All tabs preload immediately | **Automatic deferred loading** |

---

## AI Agent Integration

AdmobKit is optimized for AI coding workflows (Cursor, Claude Code, Antigravity, Copilot). Install the dedicated skill:

```bash
# Add skill to your project
npx skills add shahid0/AdmobKit-flutter
```

---

## License

AdmobKit is licensed under the [MIT License](LICENSE). Third-party template design credits are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
