# AdmobKit-flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg)](https://flutter.dev)
[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

**AdmobKit** is a production-tested Google Mobile Ads (AdMob) orchestration engine for Flutter. It eliminates startup lag, layout shifts, and ad timing guesswork with an **instant 0ms display contract**, **deterministic settlement**, and **pre-sized native ad templates**.

---

## The Real Story: Why AdmobKit Exists

In our company, junior and mid-level developers routinely got mobile ad implementations wrong:
- Splashes hung indefinitely on slow connections or failed network requests.
- Full-screen ads fired directly on top of Google UMP consent forms on fresh installs.
- Native ads suffered from nasty Cumulative Layout Shift (CLS) because container pixel heights were guessed.
- Users escaped paywall exit interstitials simply by tapping Android's hardware back button or edge-swiping.

When our teams started utilizing **AI coding agents** (Cursor, Claude Code, Copilot, Antigravity), these edge cases compounded. Agents generated ad code that appeared correct on the surface, but broke in production when users experienced poor network connectivity or offline conditions.

### The 3 Monetization Architecture Experiments

To solve this once and for all, we benchmarked and field-tested **three distinct monetization architectures** across native iOS (Swift), native Android (Kotlin), and Flutter:

| Architecture | Strategy | Pros | Honest Engineering Trade-offs (Cons) |
| :--- | :--- | :--- | :--- |
| **1. Eager Immediate-Display**<br>*(Standardized in this package)* | Always keep ads primed and ready in memory. If the user arrives at an ad touchpoint, show it with **0ms wait**. | • Maximum impression volume.<br>• Zero user wait time (no spinners or stalled navigation).<br>• Higher overall ad revenue.<br>• Deterministic UX. | • Lower show rate (impressions / requests) because cached ads may expire if unused.<br>• Slightly higher baseline RAM footprint from buffer priming. |
| **2. High-Probability Preloading**<br>*(Testing in separate plugin)* | Preload ads only when user telemetry indicates a 70–90% likelihood of reaching an ad touchpoint. | • Balanced show rate and ad freshness.<br>• Moderate request efficiency. | • Can still introduce subtle latency if user navigates faster than the ad downloads. |
| **3. Lossless / Predictive**<br>*(Testing in separate plugin)* | Load ads strictly on demand with a 50% probability heuristic, waiting for completion before proceeding. | • Highest fill-rate conservation.<br>• Lowest memory footprint. | • Stalls user navigation with loading delays, fallback timeouts, and network checks. |

**AdmobKit is our company-standardized solution for the Eager Immediate-Display strategy.** We built it into an unshakeable Flutter plugin so our engineers and AI agents literally *cannot mess up* mobile ad integrations.

We have open-sourced it for any team whose product architecture prioritizes **0ms user wait times, maximum impression volume, and rock-solid UI stability**.

---

## The Core Mental Model (The 4 Foundational Laws)

1. **The 0ms Show Contract**: `AdmobKit.show(placement, onDismissed: ...)` is strictly non-blocking. If an ad is ready in memory, it displays instantly. If unready, expired, or offline, it invokes `onDismissed` immediately with 0ms delay. Navigation is never stalled.
2. **Deterministic Settlement (`waitFor`)**: Network responses, UMP consent, and remote configs are asynchronous. Never guess completion times with `Timer()` or `Future.delayed()`. Always use `await AdmobKit.waitFor(placement)` composed in `Future.wait`.
3. **Immediate-Display Priority**: At boot or screen mount, allocate 100% of network bandwidth to the ad the user is currently looking at. Background preloads (e.g. downstream click interstitials) wait until the immediate ad resolves.
4. **Template-Bound Native Dimensions**: Native ad dimensions are strictly owned by native layouts (`small`, `medium`, `big`). Flutter code never guesses container heights—always bind to `template.height`.

---

## Quick Comparison: Stock GMA vs. AdmobKit

| Feature | Standard `google_mobile_ads` | AdmobKit (`admob_kit_flutter`) |
| :--- | :--- | :--- |
| **Fullscreen Presentation** | Manual state tracking, risk of showing stale/empty ads | **Instant 0ms display** or immediate pass-through |
| **Splash Screen Navigation** | Guesswork with `Future.delayed(3s)` or timers | **Deterministic `waitFor`** composed with Auth/Config |
| **Native Ad Container Sizing** | Manual height guessing (causes layout shifts) | **Pre-sized templates** with zero Cumulative Layout Shift |
| **Android Hardware Back** | Ignored by default (users bypass exit ads) | **Built-in `AdPaywallGuard`** with `PopScope` interception |
| **VIP / In-App Purchase** | Manual conditional checks across every widget | **Universal entitlement callback (`isPremium`)** |
| **Consent (GDPR / ATT)** | Boilerplate UMP and ATT orchestration | **Automated two-stage boot** handling UMP & ATT |
| **Network Adaptation** | Uniform timeouts regardless of connectivity | **Adaptive timeouts** (Wi-Fi vs Cellular vs Offline) |

---

## Platform Setup

### 1. Android Setup

Open `android/app/src/main/AndroidManifest.xml` and add your Google AdMob App ID inside the `<application>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="your_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Google AdMob Application ID -->
        <!-- Use test ID during development: ca-app-pub-3940256099942544~3347511713 -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713"/>

        <!-- Required for Google User Messaging Platform (UMP) -->
        <meta-data
            android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION"
            android:value="true"/>
        <meta-data
            android:name="com.google.android.gms.ads.flag.OPTIMIZE_AT_STARTUP"
            android:value="true"/>
    </application>
</manifest>
```

### 2. iOS Setup

Open `ios/Runner/Info.plist` and add your AdMob App ID, SKAdNetwork tracking identifiers, and App Tracking Transparency (ATT) description:

```xml
<key>GADApplicationIdentifier</key>
<!-- Use test ID during development: ca-app-pub-3940256099942544~1458002511 -->
<string>ca-app-pub-3940256099942544~1458002511</string>

<!-- App Tracking Transparency permission prompt description -->
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>

<!-- Google AdMob SKAdNetwork Identifier -->
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

---

## Production Canonical Recipes

### Recipe 1: Two-Stage Boot & Remote Config Orchestration

Call **Stage 1** in `main()` so GDPR/UMP consent and the GMA SDK initialize immediately at cold boot without waiting on network configs. Call **Stage 2** as soon as placement IDs are known.

```dart
import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stage 1: Initialize Consent (UMP + ATT) and GMA SDK at cold boot
  await AdmobKit.initialize(
    config: AdmobKitConfig(
      initialConcurrency: 1, // Single-thread radio to optimize slow networks
      subsequentConcurrency: 1,
      isPremium: () => UserStore.isVip, // Universal ad suppression gate
    ),
  );

  runApp(const MyApp());
}

// In your app bootstrap / remote config service:
void onRemoteConfigLoaded() {
  // Stage 2: Prime placements once IDs are resolved from network
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,
    AppAds.feedNative,
    AppAds.mainBanner,
  ]);
}
```

### Recipe 2: Composable Deterministic Splash Gate

Never use arbitrary `Timer()` or `Future.delayed()`. Compose Remote Config, Auth token restoration, and ad preloading in parallel. If the ad is ready, show it; if it fails or times out, proceed immediately with **0ms user wait**.

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  // Parallel deterministic wait for startup dependencies
  await Future.wait([
    FirebaseRemoteConfig.instance.fetchAndActivate(),
    AuthService.instance.restoreSession(),
    AdmobKit.waitFor(AppAds.splashInterstitial),
  ]);

  if (!context.mounted) return;

  // 0ms Non-blocking show contract
  AdmobKit.show(
    AppAds.splashInterstitial,
    onDismissed: () {
      Navigator.pushReplacementNamed(
        context,
        AuthService.instance.isLoggedIn ? '/home' : '/onboarding',
      );
    },
  );
}
```

### Recipe 3: Feed / List Native Ad with Zero Layout Shift

Always bind the container height directly to `template.height`. Pre-sized native templates (`big`, `medium`, `small`) map directly to native Android XML and iOS Auto Layout views.

```dart
Widget buildFeedNativeAd() {
  final template = NativeAdTemplate.medium;

  return Container(
    height: template.height, // Concrete template height (130dp) — NEVER guess
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

### Recipe 4: Navigation Shell Sticky Banner

Use `AdBannerView` at the bottom of your main navigation shell. It automatically collapses to `SizedBox.shrink()` when a user upgrades to VIP.

```dart
Scaffold(
  body: currentTabBody,
  bottomNavigationBar: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const AdBannerView(
        placement: AppAds.mainBottomBanner,
      ),
      BottomNavigationBar(...),
    ],
  ),
);
```

### Recipe 5: Paywall Exit Guard with Hardware Back Interception

Intercepts both the top visual close button **and** Android hardware back / edge-swipe navigation to trigger an exit interstitial on free tier. VIP users bypass with 0ms delay.

```dart
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: triggerDismiss, // Triggers exit ad or passes through if VIP
        ),
      ),
      body: PaywallContent(...),
    );
  },
);
```

### Recipe 6: Interval Interstitials & Rewarded Features

```dart
// Interval trigger (e.g. every 3rd completed action)
void onTaskCompleted() {
  _actionCounter++;
  if (_actionCounter % 3 == 0) {
    AdmobKit.show(AppAds.intervalInterstitial);
  }
}

// Rewarded gate (e.g. unlocking a feature or bonus export)
void onUnlockFeature() {
  AdmobKit.show(
    AppAds.rewardedBooster,
    onRewardGranted: (amount, type) {
      applyUnlockedBenefit();
    },
    onDismissed: () {
      // Refresh UI state
    },
  );
}
```

### Recipe 7: Privacy & UMP Consent Updates in Settings

Provide users with the option to change their privacy and tracking preferences at any time as required by GDPR and App Store guidelines:

```dart
ListTile(
  title: const Text('Privacy & Cookie Settings'),
  leading: const Icon(Icons.privacy_tip_outlined),
  onTap: () async {
    final updated = await AdmobKit.showPrivacyOptionsForm();
    if (updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy preferences updated.')),
      );
    }
  },
);
```

### Recipe 8: Google Ad Inspector for QA

Open the native on-device Ad Inspector to verify ad mediation, fill status, and SDK adapters during QA builds:

```dart
void openInspector() {
  AdmobKit.openAdInspector((error) {
    if (error != null) {
      debugPrint('Ad Inspector error: $error');
    }
  });
}
```

---

## Observability & Extensibility

AdmobKit is designed with clean, decoupled contracts for logging, analytics, and diagnostics:

```dart
AdmobKit.initialize(
  config: AdmobKitConfig(
    // Pipe impression-level revenue (ILRD) to Firebase / AppsFlyer / Adjust
    analytics: MyAnalyticsTracker(),

    // Pipe slow network timeouts and no-fills to Sentry / Crashlytics
    diagnostics: MyDiagnosticsTracker(),

    // Custom logger or quiet in production
    logLevel: kReleaseMode ? AdLogLevel.none : AdLogLevel.info,

    // Network timeout configuration (Wi-Fi vs Cellular)
    timeouts: AdTimeoutConfig.standard,
  ),
);
```

---

## AI Agent Integration Runbook (`skills.sh`)

[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

This package includes a specialized AI Agent skill located at [`skills/flutter-ads/SKILL.md`](skills/flutter-ads/SKILL.md).

### Automatic Skill Installation (Any Agent)

Install the skill directly into your project using the [`skills.sh`](https://skills.sh) CLI:

```bash
# Install to current project (Claude Code, Cursor, Antigravity, Copilot, etc.)
npx skills add shahid0/AdmobKit-flutter

# Or install globally across all projects
npx skills add shahid0/AdmobKit-flutter -g
```

### Golden Developer Prompts for AI Coding Assistants

When directing AI agents (Cursor, Claude Code, Antigravity, Copilot), paste these exact formulas:

- **Initial Setup**:
  > *"Integrate `admob_kit_flutter` using the `flutter-ads` skill. Configure two-stage initialization with Stage 1 in `main.dart` and Stage 2 in `RemoteConfigService`. Set startup concurrency to 1."*

- **Splash Integration**:
  > *"Implement the splash screen using the AdmobKit deterministic settlement pattern. Compose `AdmobKit.waitFor(splashInterstitial)` with app bootstrap futures, and use `AdmobKit.show` on proceed. Zero arbitrary timers and no display over UMP consent."*

- **Feed / Native Card**:
  > *"Add a medium native ad card at index 3 in the main feed using `NativeAdTemplate.medium.height` and `AdNativeView.templated`. Ensure zero cumulative layout shift."*

- **Paywall Guard**:
  > *"Wrap the paywall screen in `AdPaywallGuard` using `paywallExitInterstitial` to intercept both hardware back navigation and visual close button clicks."*

---

## License & Credits

Free and open source under the **[MIT License](LICENSE)**.

Created and maintained by **[Shahid](https://github.com/shahid0)**. You are free to use this package in commercial products and live applications without needing in-app attribution. Documentation, forks, and source distributions must preserve the original copyright notice.

