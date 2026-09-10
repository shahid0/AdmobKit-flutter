---
name: flutter-ads
description: >-
  Architect and integrate production-grade mobile ads in Flutter using the flutter_ads package.
  Enforces deterministic settlement (waitFor), two-stage initialization, UMP consent gating,
  immediate-display priority (zero startup storms), template-bound native dimensions, slow-network
  single concurrency, hardware back paywall guards, and layout-stable zero-CLS ad containers.
---

# Flutter Ads Architecture & Integration Runbook

Use this skill when integrating, maintaining, or refactoring mobile ads (Google AdMob, UMP Consent, App Open, Interstitials, Rewarded, Native, Banner) using `flutter_ads`.

---

## 1. The Core Mental Model

`flutter_ads` is an opinionated, high-performance mobile ad orchestration engine built on four foundational laws:

1. **The 0ms Show Contract**: `FlutterAds.show(placement, onDismissed: ...)` is strictly non-blocking. If an ad is ready in memory, it displays instantly. If unready, expired, or offline, it invokes `onDismissed` immediately without stalling user navigation.
2. **Deterministic Settlement (Never Blind Timers)**: Network arrivals, UMP consent, and remote configs are asynchronous. Never guess completion times with `Timer()` or `Future.delayed()`. Always use `await FlutterAds.waitFor(placement)` composed with startup futures.
3. **Immediate-Display Priority (Zero Startup Preload Storms)**: The ad the user is looking at right now has absolute priority. At cold boot or screen mount, allocate 100% of network bandwidth to the visible ad. Background preloads (resume ads, click interstitials) only initiate *after* the immediate screen's ads resolve.
4. **Template-Bound Dimensions**: Native ad dimensions are strictly owned by native layouts (`small`, `medium`, `big`). Flutter code must never guess pixel heights—always read `template.height` and `template.width`.

---

## 2. Invariant Negative Constraints (The "DO NOTs")

AI agents must strictly follow these negative constraints:

- ❌ **DO NOT use `Timer` or `Future.delayed` for ad readiness or splash navigation.**  
  Always use `await FlutterAds.waitFor(...)` with a reasonable timeout fallback.
- ❌ **DO NOT fire ads before or over the UMP consent form on fresh installs.**  
  Consent resolution must precede ad display and startup navigation.
- ❌ **DO NOT trigger startup preload storms at cold launch.**  
  Only request ads strictly required for the immediate screen. Background preloads for downstream funnels must wait until the immediate ad resolves.
- ❌ **DO NOT guess or hardcode native ad container heights (e.g. `height: 300`).**  
  Always use `NativeAdTemplate.big.height`, `medium.height`, or `small.height`.
- ❌ **DO NOT attach paywall exit interstitials solely to the UI 'X' button.**  
  Always intercept the Android system hardware back button / swipe gesture using `AdPaywallGuard`.
- ❌ **DO NOT delay `FlutterAds.initialize()` behind Remote Config.**  
  Always initialize UMP & SDK at cold boot (`main()`), then register placements via `FlutterAds.registerPlacements(...)` when Remote Config finishes.
- ❌ **DO NOT fire App Open ads when resuming from a fullscreen ad.**  
  Always check `FlutterAds.isShowingAd` and ensure modal/paywall routes are guarded.
- ❌ **DO NOT set `loadOnce: false` on one-time placements (e.g. splash, onboarding).**  
  One-time placements must declare `loadOnce: true` to prevent wasteful auto-replenishment.
- ❌ **DO NOT add app UI dependencies to the root `flutter_ads` package.**  
  Keep the core package lightweight (`google_mobile_ads`, `connectivity_plus`). App-level packages go in `example/pubspec.yaml`.
- ❌ **DO NOT write fluff comments or step-by-step banners.**  
  Code must be self-explanatory. Retain only load-bearing explanations.

---

## 3. Production Canonical Recipes

### Recipe 1: Two-Stage Initialization & Remote Config Orchestration

Call Stage 1 in `main()` so GDPR/UMP consent and GMA SDK initialize immediately without waiting on network config. Call Stage 2 as soon as placement IDs are known.

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stage 1: Initialize Consent (UMP) and GMA SDK immediately at cold boot
  await FlutterAds.initialize(
    config: const FlutterAdsConfig(
      initialConcurrency: 1, // Single-thread radio to optimize slow networks
      subsequentConcurrency: 1,
    ),
  );

  runApp(const MyApp());
}

// In your app bootstrap / remote config service:
void onRemoteConfigLoaded() {
  // Stage 2: Prime placements once IDs are resolved from network
  FlutterAds.registerPlacements([
    SampleAds.splashInterstitial,
    SampleAds.homeNative,
    SampleAds.mainBanner,
  ]);
}
```

---

### Recipe 2: Composable Deterministic Splash Gate

Never use arbitrary timers. Compose Remote Config, Auth token restoration, and ad preloading in parallel. If the ad is ready, show it; if it fails or times out, proceed immediately with 0ms user wait.

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  // Parallel deterministic wait for startup dependencies
  await Future.wait([
    FirebaseRemoteConfig.instance.fetchAndActivate(),
    AuthService.instance.restoreSession(),
    FlutterAds.waitFor(SampleAds.splashInterstitial),
  ]);

  if (!context.mounted) return;

  // 0ms Non-blocking show contract
  FlutterAds.show(
    SampleAds.splashInterstitial,
    onDismissed: () {
      Navigator.pushReplacementNamed(
        context,
        AuthService.instance.isLoggedIn ? '/home' : '/onboarding',
      );
    },
  );
}
```

---

### Recipe 3: Feed / List Native Ad with Zero Layout Shift

Always bind the container height directly to `template.height`. Wrap in an elevated card to match your app's design system.

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
      placement: SampleAds.feedNative,
      template: template,
    ),
  );
}
```

---

### Recipe 4: Navigation Shell Sticky Banner

Use `AdBannerView` at the bottom of the main navigation shell. Automatically collapses to `SizedBox.shrink()` when user upgrades to VIP.

```dart
Scaffold(
  body: currentTabBody,
  bottomNavigationBar: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const AdBannerView(
        placement: SampleAds.mainBottomBanner,
      ),
      BottomNavigationBar(...),
    ],
  ),
);
```

---

### Recipe 5: Paywall Exit Guard with Hardware Back Interception

Intercepts both the top visual close button **and** Android hardware back / edge-swipe navigation to trigger an exit interstitial on free tier. VIP users bypass with 0ms delay.

```dart
AdPaywallGuard(
  placement: SampleAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: triggerDismiss, // Triggers exit guard
        ),
      ),
      body: PaywallContent(...),
    );
  },
);
```

---

### Recipe 6: Interval Interstitial & Rewarded Features

```dart
// Interval trigger (e.g. every 3rd completed task or item action)
void onTaskCompleted() {
  _completedTasksCount++;
  if (_completedTasksCount % 3 == 0) {
    FlutterAds.show(SampleAds.intervalInterstitial);
  }
}

// Rewarded gate (e.g. unlocking a feature export or bonus state)
void onUnlockFeature() {
  FlutterAds.show(
    SampleAds.rewardedBooster,
    onRewardGranted: (amount, type) {
      applyUnlockedBenefit();
    },
    onDismissed: () {
      // Refresh UI state
    },
  );
}
```

---

### Recipe 7: Decoupled VIP / "Any Purchase" Ad Suppression

Ad eligibility must be a decoupled boolean gate. If the user has made *any* qualifying purchase (subscription or one-time pack), ads remain permanently suppressed.

```dart
FlutterAds.initialize(
  config: FlutterAdsConfig(
    isPremium: () => purchaseService.hasPurchasedAnyProduct,
  ),
);
```

---

## 4. Golden Developer Prompts

When directing an AI agent to build or update ad flows, use these prompt formulas:

- **Initial Setup**:
  > *"Integrate `flutter_ads` using the `flutter-ads` skill. Configure two-stage initialization with Stage 1 in `main.dart` and Stage 2 in `RemoteConfigService`. Set startup concurrency to 1."*

- **Splash Integration**:
  > *"Implement the splash screen using the `flutter-ads` deterministic settlement pattern. Compose `FlutterAds.waitFor(splashInterstitial)` with app bootstrap futures, and use `FlutterAds.show` on proceed. No arbitrary timers and no display over UMP consent."*

- **Feed / Native Card**:
  > *"Add a medium native ad card at index 3 in the main feed using `NativeAdTemplate.medium.height` and `AdNativeView.templated`. Ensure zero cumulative layout shift."*

- **Paywall Guard**:
  > *"Wrap the paywall screen in `AdPaywallGuard` using `paywallExitInterstitial` to intercept both hardware back navigation and visual close button clicks."*

---

## 5. Verification Checklist

Before completing any ad integration task, verify:
1. `flutter analyze` has 0 warnings and 0 errors.
2. No `Timer` or `Future.delayed` was introduced for ad timing.
3. No native ad container has a guessed pixel height.
4. The paywall handles both visual close and hardware back navigation.
5. Startup preloads are restricted to the immediate launch screen.
6. One-time ads (`splash`, `onboarding`) have `loadOnce: true`.
