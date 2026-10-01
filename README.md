# AdmobKit for Flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg)](https://flutter.dev)
[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

**AdmobKit** is a production-grade Google Mobile Ads (AdMob) orchestration engine for Flutter. It eliminates ad loading lag, cumulative layout shifts (CLS), and presentation race conditions through an **instant 0ms display contract**, **deterministic settlement**, **25 pre-dimensioned native templates**, and **automated GDPR/UMP consent**.

> **Package Import:**
> ```dart
> import 'package:admob_kit_flutter/admob_kit_flutter.dart';
> ```

---

## Why AdmobKit?

Standard `google_mobile_ads` implementations frequently suffer from blank flashes, layout shifts, multi-widget lifecycle crashes, and race conditions during screen transitions. AdmobKit provides structural architectural solutions:

| Problem in Standard AdMob | AdmobKit Solution |
| :--- | :--- |
| **Cumulative Layout Shift (CLS)** | Pre-dimensioned native templates & adaptive banner containers reserve exact space before ads load. |
| **`AdWidget already in tree` crash** | Demand-based instance leasing guarantees each widget receives an exclusively-owned ad object. |
| **Stuttered UI / Navigation Hangs** | **0ms Show Contract**: memory-cached ads render instantly; unready ads dismiss immediately with 0ms delay. |
| **Complex Native Android XML / iOS XIB** | 25 built-in native layouts rendered directly by native platforms with zero custom native code required. |
| **Splash Presentation Races** | Deterministic `waitFor(placement)` settlement composed with app startup tasks in `Future.wait`. |
| **GDPR / ATT Consent Boilerplate** | Automated two-stage initialization pipeline with built-in UMP consent collection. |

---

## Table of Contents

- [Quickstart](#quickstart)
- [Ad Formats & Code Examples](#ad-formats--code-examples)
  - [Native Ads & 25 Built-in Templates](#native-ads--25-built-in-templates)
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
    template: NativeAdTemplate.splitMediaLeft,
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

### Native Ads & 25 Built-in Templates

AdmobKit eliminates the need to author Android XML or iOS XIB files. Choose from **25 pre-built platform-rendered native templates** grouped by visual topology:

| Family | Height | Layout Topology | Canonical Preset |
| :--- | :--- | :--- | :--- |
| **Row** (8 variants) | **104 logical px** | `rowWithLeadingIcon`, `rowTextOnly`, `rowWithTrailingIcon`, `rowExpandedText`, `rowTextOnlyExpanded`, `rowMinimalText`, `rowLeadingCta`, `rowLeadingCtaCompact` | `NativeAdTemplate.compactRow` |
| **Split & Card** (6 variants) | **160 logical px** | `splitMediaLeft`, `splitMediaRight`, `cardContentTop`, `cardActionTop`, `cardCleanContentTop`, `cardCleanActionTop` | `NativeAdTemplate.splitMedia`, `stackedCard` |
| **Feed Card** (6 variants) | **340 logical px** | `feedMediaFirst`, `feedContentFirst`, `feedActionMiddle`, `feedTrailingIcon`, `feedMediaTopSideCta`, `feedContentTopSideCta` | `NativeAdTemplate.feedCard` |
| **Fullscreen** (5 variants) | **Bounded parent (min 320px)** | `fullscreenMediaFirst`, `fullscreenContentFirst`, `fullscreenTrailingIcon`, `fullscreenMediaSideCta`, `fullscreenActionMiddle` | `NativeAdTemplate.fullscreen` |

> [!NOTE]
> Backward compatibility: Legacy identifiers (`small1`–`small8`, `medium1`–`medium6`, `large1`–`large6`, `fullscreen1`–`fullscreen5`) remain available as `@Deprecated` aliases that automatically map to their semantic equivalents.

Mounting a zero-CLS native ad in a feed:

```dart
Widget buildNativeFeedItem() {
  return Container(
    height: AppAds.feedNative.template.height, // 160 logical px
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
  appBar: AppBar(leading: const CloseButton()),
  body: const SafeArea(
    child: AdNativeView(placement: fullscreenPlacement),
  ),
);
```

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

Theme all 25 native templates with `NativeAdStyle`. Changes apply immediately to pending, cached, and rendered ads without reloading:

```dart
// 1. Initial Style on Placement
const feedNative = NativePlacement(
  id: 'feed_native',
  template: NativeAdTemplate.splitMediaLeft,
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
| **Native Ad Layouts** | Requires custom Android XML & iOS XIB files | **25 Built-in platform templates** (Zero XML/XIB needed) |
| **Dynamic Styling** | Static compile-time files | **Live runtime theming** via Pigeon (`setNativeStyle`) |
| **CTA Button Radius** | Fixed native drawable | **Configurable radius** (Square, rounded, or pill) |
| **Layout Shift (CLS)** | Unpredictable container sizing | **Zero CLS** (Template pre-dimensioning) |
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
