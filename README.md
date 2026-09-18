# AdmobKit-flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-orange.svg)](https://flutter.dev)
[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

**AdmobKit** is a production-tested Google Mobile Ads (AdMob) orchestration engine for Flutter. It eliminates startup lag, layout shifts, and ad timing guesswork with an **instant 0ms display contract**, **deterministic settlement**, **priority-tiered preloading**, and **pre-sized native ad templates**.

> **Import:** `import 'package:admob_kit_flutter/admob_kit_flutter.dart';` — the facade is `AdmobKit`.

**Found a bug or unexpected behavior? Please [open a GitHub issue](https://github.com/shahid0/AdmobKit-flutter/issues/new/choose) with your placement config and logs — real reports fix this engine for everyone. Avoid working around engine behavior with "band-aid" patches (timers, delays, manual ad instantiation); they reintroduce the exact races this package was built to eliminate.**

---

## Table of Contents

| | | |
| :--- | :--- | :--- |
| [The 4 Foundational Laws](#the-4-foundational-laws) | [Quickstart](#quickstart) | [How Ads Load](#how-ads-load-the-priority-capacity-model) |
| [API Surface](#api-surface) | [Use Cases & Scenarios](#use-cases--scenarios) | [Analytics vs Diagnostics](#analytics-vs-diagnostics-which-one-and-why-both-exist) |
| [Stock GMA vs AdmobKit](#stock-gma-vs-admobkit) | [The 3 Architectures](#the-3-monetization-architecture-experiments) | [Platform Setup](#platform-setup) |
| [Observability Wiring](#observability-wiring) | [AI Agent Runbook](#ai-agent-integration-runbook) | [Architecture](#architecture-for-contributors) |

---

## The 4 Foundational Laws

Every part of the engine enforces these. Internalize them before writing ad code.

1. **The 0ms Show Contract** — `AdmobKit.show(placement, onDismissed: ...)` is strictly non-blocking. Ad in memory → displays instantly. Unready, expired, or offline → `onDismissed` fires immediately with **0ms delay**. User navigation is never stalled.
2. **Deterministic Settlement** — Never guess when an ad arrives with `Timer()` or `Future.delayed()`. Use `await AdmobKit.waitFor(placement)` (returns `bool`), composed in `Future.wait` with auth/config futures.
3. **Immediate-Display Priority** — The ad the user is looking at wins the network. Visible-screen leases and `waitFor` calls promote their placement to the `immediate` tier automatically, preempting background preloads.
4. **Template-Bound Native Dimensions** — Native container sizes are owned by native layouts (`small` 74dp, `medium` 130dp, `big` 300dp). Flutter never guesses heights — always bind `template.height`.

---

## Quickstart

Install, boot in two stages, display. That's the whole loop.

```bash
flutter pub add admob_kit_flutter
```

**1. Declare placements** (one file, type-safe):

```dart
// lib/ads/app_ads.dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class AppAds {
  static const splashInterstitial = InterstitialPlacement(
    id: 'splash_interstitial',
    androidId: AdMobTestIds.interstitialAndroid, // swap for production IDs
    iosId: AdMobTestIds.interstitialIos,
    isSplash: true,
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
}
```

**2. Stage 1 — cold boot** (`main.dart`, before anything network-dependent):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdmobKit.initialize(
    config: const AdmobKitConfig(
      initialConcurrency: 1,   // single-radio discipline on slow networks
      subsequentConcurrency: 1,
      isPremium: () => UserStore.isVip, // universal ad suppression gate
    ),
  );

  runApp(const MyApp());
}
```

**3. Stage 2 — when placement IDs are known** (e.g. Remote Config resolves):

```dart
void onRemoteConfigLoaded() {
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,
    AppAds.feedNative,
    AppAds.bottomBanner,
  ]);
}
```

**4. Render** — zero layout shift, zero manual state:

```dart
const AdBannerView(placement: AppAds.bottomBanner)
```

**5. Show fullscreen** — 0ms or pass-through:

```dart
AdmobKit.show(
  AppAds.splashInterstitial,
  onDismissed: () => Navigator.pushReplacementNamed(context, '/home'),
);
```

Platform manifest setup (Android `APPLICATION_ID`, iOS `GADApplicationIdentifier` + SKAdNetwork) is in [Platform Setup](#platform-setup). A complete working app with every placement type lives in [`example/`](example/).

---

## How Ads Load: The Priority & Capacity Model

This is the engine's core scheduling logic — understanding it explains *why* ads appear when they do.

### Priority tiers

The queue is a five-tier priority dispatcher. Lower rank drains first; within the same tier, inline (banner/native) placements load before fullscreen ones.

| Tier | Rank | Who belongs here | Set by |
| :--- | :--- | :--- | :--- |
| `AdPriority.splash` | 0 | Cold-start / splash placements. Drained before everything else. | `isSplash: true` on any placement |
| `AdPriority.immediate` | 1 | The screen the user is on **right now**. | Automatic: any `waitFor()` or empty-buffer lease promotes its placement here |
| `AdPriority.high` | 2 | Early-session funnels: onboarding, main navigation. | Default for non-splash interstitials & app-open |
| `AdPriority.medium` | 3 | Recurring triggers, standard in-app placements. | Default for banners, natives, rewarded |
| `AdPriority.low` | 4 | Background preloads for later funnels. | Explicit `priority: AdPriority.low` |

**Merging & scoping rules:**

- Two `preload()` calls for the same **fullscreen** placement merge into one network request (deduplicated by placement ID).
- Each **inline** (banner/native) lease is its own exclusive task — two widgets on one screen never share an ad instance (`AdWidget` would crash otherwise). The capacity model bounds how many run at once.
- A `waitFor()` or widget lease on an empty buffer **promotes** all of that placement's queued tasks to `immediate`, jumping ahead of `medium`/`low` background work.

### Capacity: how deep each buffer goes (usually leave it alone) (usually leave it alone)

Each placement keeps a warm in-memory buffer of loaded ads. The default depth of **1 is correct for the vast majority of apps** — one warm ad per placement, replenished automatically after consumption.

> **Discouraged unless you truly need it:** `placementCapacities` exists for one specific shape — *multiple widgets showing the same placement simultaneously on one screen* (e.g. two native cards visible at once). Reaching for it "to be safe" causes real problems: deeper buffers hold more expiring ads (wasted requests, lower show rate), inflate memory, and — because buffered ads age out while waiting — can *increase* the chance a user hits an empty buffer. Do not add capacities speculatively; add one only when you can point at a screen where two widgets with the same placement are mounted at the same time, and set it to exactly that count.

```dart
// Only for genuinely simultaneous same-placement widgets:
AdmobKit.registerPlacements(placements, placementCapacities: {
  'feed_native': 2,  // two feed cards show natives at the same time
});
// Everything else: omit — default depth 1.
```

When a widget leases an ad on an empty buffer, it registers demand; the replenished ad is delivered **directly to that widget** (never to the buffer), then the buffer re-warms for the next viewer. Duplicate network requests for the same demand are structurally impossible — you never need capacities to "prevent duplicates".

### Concurrency

`initialConcurrency` (default 1) throttles the startup batch; `subsequentConcurrency` (default 1) governs everything after. Keep both at 1 unless you have measured that parallel AdMob requests don't hurt your fill rate on cellular — serialized loads are the whole point on slow networks.

### Expiry & retries

- Ads expire from memory after `adTtl` (default **50 minutes**) and are evicted + reloaded on next use.
- Failed loads retry with backoff via `RetryScheduler` (default: max 4 attempts; AdMob code 1 = fatal, never retried; code 3 no-fill ≈ 10s×attempt backoff; network errors exponential).

---

## API Surface

### Facade — `AdmobKit`

| Member | Signature | Contract |
| :--- | :--- | :--- |
| `initialize` | `Future<void> initialize({AdmobKitConfig config})` | Stage 1: UMP consent + GMA SDK at cold boot. Call once in `main()`. |
| `registerPlacements` | `void registerPlacements(Iterable<AdPlacement>, {Map<String,int>? placementCapacities})` | Stage 2: prime the eager pool. Callable multiple times. |
| `show` | `void show(FullscreenPlacement, {VoidCallback? onDismissed, void Function(num, String)? onRewardGranted, VoidCallback? onDisplayed})` | 0ms non-blocking. Second concurrent fullscreen request is rejected → its `onDismissed` fires immediately. |
| `waitFor` | `Future<bool> waitFor(AdPlacement, {Duration? timeout})` | Deterministic settlement. `true` = ready in memory; `false` = failed / timed out / premium. Promotes to `immediate`. |
| `isReady` | `bool isReady(AdPlacement)` | Fresh ad sitting in the buffer right now? |
| `isLoading` | `bool isLoading(AdPlacement)` | A download for this placement is in flight. |
| `getState` | `AdPlacementState getState(AdPlacement)` | See [state machine](#placement-state-machine). |
| `watchState` | `Stream<AdPlacementState> watchState(AdPlacement)` | Reactive stream of state transitions (custom loading UIs). |
| `preload` | `void preload(AdPlacement)` | Manual on-demand top-up. No-ops when buffer + pending already meet capacity. |
| `leaseInlineAd` | `Future<dynamic> leaseInlineAd(InlinePlacement, {Duration? timeout})` | Package-internal. Used by `AdBannerView` / `AdNativeView` — do not call from app code. |
| `isShowingAd` | `bool get isShowingAd` | A fullscreen ad is currently on screen (gate App Open re-entry with this). |
| `isUserPremium` | `bool get isUserPremium` | Effective entitlement state. |
| `canRequestAds` | `bool get canRequestAds` | Consent outcome. |
| `showPrivacyOptionsForm` | `Future<bool> showPrivacyOptionsForm()` | UMP privacy options (GDPR settings screen). |
| `openAdInspector` | `void openAdInspector([void Function(String?)? onComplete])` | Native on-device Ad Inspector for QA. |

### `AdmobKitConfig`

| Field | Type / Default | Purpose |
| :--- | :--- | :--- |
| `placements` | `List<AdPlacement>?` | Prime immediately at Stage 1 (optional; usually Stage 2 instead). |
| `requestConsent` | `bool = true` | Run the UMP + ATT pipeline. |
| `consentTestConfig` | `ConsentTestConfig?` | Simulate EEA geography + test devices for consent QA. |
| `isPremium` | `bool Function()?` | Universal suppression gate — VIP users get zero ad traffic, everywhere. |
| `timeouts` | `AdTimeoutConfig = standard` | Network-adaptive timeout policies (see below). |
| `retryScheduler` | `RetryScheduler?` | Custom backoff policy. |
| `analytics` | `AdAnalyticsTracker?` | Marketing/revenue funnel events (see [Analytics vs Diagnostics](#analytics-vs-diagnostics-which-one-and-why-both-exist)). |
| `diagnostics` | `AdDiagnosticsTracker?` | Engineering health telemetry (see same section). |
| `logLevel` | `AdLogLevel?` | `verbose` → `none`. Use `none` in release builds. |
| `testDeviceIds` | `List<String>?` | GMA test devices. |
| `initializeNativeGma` | `bool = true` | Registers native ad factories + starts GMA. |
| `adTtl` | `Duration = 50min` | In-memory ad freshness window. |
| `initialConcurrency` | `int = 1` | Parallel downloads during the startup batch. |
| `subsequentConcurrency` | `int = 1` | Parallel downloads for replenishment/secondary preloads. |
| `placementCapacities` | `Map<String, int>?` | Warm-buffer depth per placement ID (default 1). **Leave unset unless two widgets share a placement simultaneously** — see [capacity guidance](#capacity-how-deep-each-buffer-goes-usually-leave-it-alone). |

### Placement types & their defaults

| Placement | Kind | Default priority | Splash default | Typical use |
| :--- | :--- | :--- | :--- | :--- |
| `InterstitialPlacement` | Fullscreen | `high` | `splash` | Transitions, exits, intervals |
| `AppOpenPlacement` | Fullscreen | `high` | `splash` | Cold/resume branding |
| `RewardedPlacement` | Fullscreen | `medium` | — | Unlock features, bonuses |
| `RewardedInterstitialPlacement` | Fullscreen | `medium` | — | Natural-break monetization |
| `BannerPlacement` | Inline | `medium` | `splash` | Sticky shells, lists |
| `NativePlacement.small/medium/big` | Inline | `medium` | `splash` | Feed cards, in-content units |

All accept `priority:` to override, `loadOnce:` (one-time placements — set `true` for splash/onboarding to prevent wasteful replenishment), and `isSplash:` (routes to the dedicated splash tier + deterministic settlement on show).

### Native templates

| Template | Height | Native factory ID |
| :--- | :--- | :--- |
| `NativeAdTemplate.small` / `NativePlacement.small` | 74dp | `smallNativeAd` |
| `NativeAdTemplate.medium` / `NativePlacement.medium` | 130dp | `listTileMedium` |
| `NativeAdTemplate.big` / `NativePlacement.big` | 300dp | `bigNativeAd` |

### Placement state machine

```
unloaded ──▶ loading ──▶ ready ──▶ (leased/consumed) ──▶ unloaded
                │                                    
                └──▶ error (circuit breaker / fatal AdMob code)
```

`watchState` streams these transitions per placement; `getState` snapshots. Render loading UI on `loading`, the ad on `ready`, empty state on `error`.

---

## Use Cases & Scenarios

Concrete solutions to the situations every ad-integrated app hits. All are handled by the engine — the only wrong move is hand-rolling them.

### Two widgets, one placement (feed with multiple native cards)

The classic AdMob crash — `This AdWidget is already in the Widget tree` — happens when the same ad object renders twice. AdmobKit makes it impossible: each widget's lease returns its own exclusively-owned ad instance — even without any capacity registration.

```dart
// Only because TWO cards are visible simultaneously for the SAME placement.
// If your feed shows just one native card at a time: omit capacities entirely.
AdmobKit.registerPlacements([AppAds.feedNative],
    placementCapacities: {'feed_native': 2});

// Both cards lease independently — no shared instances, no crashes,
// no duplicate network requests for the same demand.
ListView.builder(
  itemBuilder: (context, i) => i == 2
      ? const AdNativeView.templated(placement: AppAds.feedNative, template: NativeAdTemplate.medium)
      : TaskCard(tasks[i]),
);
```

See [Capacity](#capacity-how-deep-each-buffer-goes-usually-leave-it-alone) for when this knob is (and isn't) worth touching.

### Ads in tabs (`IndexedStack`, bottom-nav shells)

Ad loads **defer** until a tab is actually visible — hidden tabs consume zero network. The gate combines `TickerMode` (route coverage) and `Visibility` (hidden `IndexedStack` tabs), and reacts automatically when the tab flips.

```dart
IndexedStack(
  index: currentIndex,
  children: const [
    TasksTab(),   // contains AdNativeView → loads only when this tab is front
    FocusTab(),
    AnalyticsTab(),
  ],
);
```

Works out of the box with `IndexedStack` and covered navigation routes. **Caveat:** `TabBarView`/`PageView` do *not* gate `TickerMode` — wrap those pages explicitly:

```dart
TickerMode(enabled: pageController.page == 0, child: PageOne())
// or Visibility(visible: currentIndex == 0, child: PageOne())
```

### One-time screens: registration is forever (the loadOnce trap)

`loadOnce: true` means **"load this ad once per install, ever."** The engine marks the placement consumed permanently — which is exactly what splash and onboarding want. But it creates an asymmetry you must respect at registration time:

> **If a screen or feature only exists for first-run users, do NOT register its ad placement — or guard the registration itself.** A registered `loadOnce` placement is primed at Stage 2 whether or not the user ever reaches that screen. Worse: if the user *skips* onboarding without consuming the ad (e.g. signed in with an existing account), the ad sits consumed-but-unshown, and on every subsequent launch nothing loads — correct for the ad, but the point is the *screen* is also one-time.

```dart
// ❌ Wrong: onboarding exists only for new installs, but its placement is
// registered unconditionally. Second-launch users pay for a load they'll
// never see, and skip-paths leave phantom consumed state.
AdmobKit.registerPlacements([AppAds.onboardingNative]);

// ✅ Right: the caller knows the routing context — register conditionally.
void onRemoteConfigLoaded({required bool isFirstLaunch}) {
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,   // every launch: fine (shown every launch)
    AppAds.feedNative,
    AppAds.bottomBanner,
    if (isFirstLaunch) AppAds.onboardingNative,
  ]);
}
```

The general rule: **the placement list should mirror what can actually be *shown* on this install** — not the app's full static inventory. `registerPlacements` is callable multiple times, so register a screen's placement when (or just before) that screen becomes reachable. Never registered = never loaded = zero waste.

### Slow splash on a bad connection

`isSplash: true` + `loadOnce: true`. If the ad is already in memory at show time → 0ms display. If it's still downloading → the presentation mutex is held, the splash **deterministically settles** (shows when ready, or continues the flow on failure/timeout — no 15s blank screen, no dropped splash), and any concurrent fullscreen trigger is rejected cleanly.

```dart
await Future.wait([
  FirebaseRemoteConfig.instance.fetchAndActivate(),
  AuthService.instance.restoreSession(),
  AdmobKit.waitFor(AppAds.splashInterstitial),
]);

AdmobKit.show(
  AppAds.splashInterstitial,
  onDismissed: () => Navigator.pushReplacementNamed(
      context, AuthService.instance.isLoggedIn ? '/home' : '/onboarding'),
);
```

### VIP / purchased users see zero ads

One callback, enforced everywhere: preloads are skipped, `show()` passes through to `onDismissed`, widgets collapse to `SizedBox.shrink` (zero reserved space). No ad traffic at all.

```dart
isPremium: () => purchaseService.hasPurchasedAnyProduct,
```

### Paywall exit — hardware back AND close button

`AdPaywallGuard` intercepts Android hardware back / edge swipe **and** wires your visual close button through the same exit-interstitial flow. Purchased users bypass with 0ms.

```dart
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: triggerDismiss,
    )),
    body: PaywallContent(...),
  ),
);
```

### App Open ads without re-entry storms

Firing App Open on every resume (including resumes *from another fullscreen ad*) is the classic policy-violation loop. Gate it:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && !AdmobKit.isShowingAd) {
    AdmobKit.show(AppAds.appOpen);
  }
}
```

### Interval interstitials & rewarded unlocks

```dart
// Every 3rd completed action
void onTaskCompleted() {
  if (++_actionCounter % 3 == 0) AdmobKit.show(AppAds.intervalInterstitial);
}

// Rewarded gate
AdmobKit.show(
  AppAds.rewardedBooster,
  onRewardGranted: (amount, type) => applyUnlockedBenefit(),
  onDismissed: () => setState(() {}),
);
```

### GDPR consent testing (EEA simulation)

Verify consent behavior without traveling to Europe:

```dart
await AdmobKit.initialize(
  config: AdmobKitConfig(
    requestConsent: true,
    consentTestConfig: ConsentTestConfig(
      debugGeography: DebugGeography.debugGeographyEea,
      testIdentifiers: ['YOUR_TEST_DEVICE_HASH'],
    ),
  ),
);
```

### Privacy settings & QA tooling

```dart
// Settings screen — GDPR requires an always-available privacy option
ListTile(
  title: const Text('Privacy & Cookie Settings'),
  onTap: () async {
    final updated = await AdmobKit.showPrivacyOptionsForm();
    if (updated && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy preferences updated.')));
    }
  },
);

// QA builds — live SDK state inspection
AdmobKit.openAdInspector((error) => debugPrint('Inspector: $error'));
```

### Offline behavior (cold start with no network)

Every path is defined: `waitFor` resolves `false` on timeout, `show` invokes `onDismissed` immediately (navigation proceeds), widgets settle into their empty state instead of infinite spinners, loads retry with backoff when connectivity returns, and an offline tab that failed once **retries when reactivated** after reconnection. Your UI never hangs — render an empty state or retry affordance on the `error`/timeout signals.

---

## Analytics vs Diagnostics — Which One, and Why Both Exist

They answer different questions for different audiences. Wire both in production; neither costs a request.

### `AdAnalyticsTracker` — "How is monetization performing?"

**Audience:** product, marketing, LTV/ROAS pipelines. Pipe to **Firebase Analytics, AppsFlyer, Adjust, Mixpanel**.

| Callback | Fires when | Typical destination |
| :--- | :--- | :--- |
| `onAdRequested` | Load dispatched | Funnel step 1 |
| `onAdLoaded(placement, loadTime)` | Ad ready in memory | Fill-rate dashboards |
| `onAdFailedToLoad` | Request failed | Funnel drop-off |
| `onAdDisplayed` | Impression rendered | **Impression volume** (your core KPI) |
| `onAdDismissed` | Fullscreen closed | Session-flow analysis |
| `onAdClicked` | User tapped ad | CTR |
| `onPaidEvent(placement, AdRevenueValue)` | **Impression-level revenue (ILRD)** | **LTV / ROAS / ARPU** |

```dart
class FirebaseAdAnalytics implements AdAnalyticsTracker {
  @override
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue) {
    FirebaseAnalytics.instance.logAdImpression(
      adUnitName: placement.id,
      currencyCode: revenue.currencyCode,
      value: revenue.value,           // micros/1e6, e.g. 0.0125
    );
  }
  // ... other callbacks → funnel events
}
```

`AdRevenueValue` carries `micros`, `currencyCode`, and `precision` (`estimated` / `publisherProvided` / `precise`) — exactly what revenue attribution backends expect.

### `AdDiagnosticsTracker` — "Is the ad engine healthy in production?"

**Audience:** engineering, on-call, QA. Pipe to **Sentry, Crashlytics, Datadog** — breadcrumbs and custom events, not marketing funnels.

| Event | Meaning | You should care when |
| :--- | :--- | :--- |
| `requested` / `loaded` / `failedToLoad` | Load lifecycle with `admobErrorCode` | Error spikes per placement |
| `timeout` | Exceeded network-adaptive threshold | Slow-network regions suffering |
| `retryScheduled` / `circuitBroken` | Backoff scheduled / retries exhausted | Persistent no-fill or bad unit IDs |
| `blackHoleSuspected` | ≥2 consecutive cellular timeouts — captive portal / dead data | Field anomaly detection |
| `staleEvicted` | Buffer ad expired past TTL | Capacities too deep for session length |
| `displayed` / `dismissed` | Presentation lifecycle | Show-rate math |

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

### Decision rule

- **Shipping an app with revenue targets** → implement both. Analytics for the business, diagnostics for engineering.
- **Internal/QA tools or pre-revenue** → diagnostics alone; `logLevel` gives you the rest locally.
- **Neither** → the engine still logs through `AdLogLevel` — start there, add contracts when you need them in a dashboard.

---

## Stock GMA vs. AdmobKit

| Feature | Standard `google_mobile_ads` | AdmobKit |
| :--- | :--- | :--- |
| **Fullscreen presentation** | Manual state tracking; stale/empty ads | Instant 0ms display or immediate pass-through |
| **Splash navigation** | `Future.delayed(3s)` guesswork | Deterministic `waitFor` + mutex-guarded settle |
| **Native container sizing** | Guessed heights → layout shift | Pre-sized templates, zero CLS |
| **Two natives, one screen** | Shared instances → `AdWidget` crash | Exclusive leases + capacity buffers |
| **Tab-hidden ads** | All tabs load at mount | `IndexedStack`/route-aware deferral |
| **Android hardware back** | Users bypass exit ads | `AdPaywallGuard` with `PopScope` interception |
| **VIP suppression** | Manual checks in every widget | One `isPremium` callback, enforced everywhere |
| **Consent (GDPR/ATT)** | Boilerplate UMP orchestration | Automated two-stage boot |
| **Offline / slow networks** | Uniform timeouts, hang-prone | Adaptive timeouts, fast-fail, black-hole detection |
| **Priority scheduling** | None — request order = luck | 5-tier queue with automatic promotion |

---

## The 3 Monetization Architecture Experiments

AdmobKit standardizes one of three field-tested strategies. The honest trade-offs:

| Architecture | Strategy | Pros | Trade-offs |
| :--- | :--- | :--- | :--- |
| **1. Eager Immediate-Display** *(this package)* | Always keep ads primed; show with 0ms wait at the touchpoint. | Max impression volume, zero user wait, deterministic UX, higher revenue. | Lower show-rate ratio (cached ads can expire); slightly higher RAM from buffering. |
| **2. High-Probability Preloading** *(separate plugin)* | Preload when telemetry predicts 70–90% likelihood of reaching the touchpoint. | Balanced show rate and freshness; moderate request efficiency. | Subtle latency if users navigate faster than downloads. |
| **3. Lossless / Predictive** *(separate plugin)* | Load strictly on demand behind a 50% probability heuristic, waiting for completion. | Highest fill-rate conservation; lowest memory. | Stalls navigation with loading delays and fallback timeouts. |

AdmobKit exists because Architecture 1 maximizes what most ad-monetized products optimize for: impressions and UX determinism.

<details>
<summary><strong>Why we built this (the short version)</strong></summary>

Junior and mid-level developers on our teams routinely broke mobile ad integrations: splashes hanging on slow connections, fullscreen ads firing over UMP consent forms on fresh installs, CLS from guessed container heights, paywall exit interstitials bypassed via hardware back. When AI coding agents entered the workflow, these failure modes compounded — generated code looked correct and broke in production under poor connectivity.

We benchmarked the three architectures above, standardized the winner, and engineered it into this package so human engineers and AI agents *cannot* get the fundamentals wrong. It is open-sourced for any team that prioritizes 0ms user wait, maximum impression volume, and rock-solid UI stability.

</details>

---

## Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<application ...>
    <!-- Google AdMob Application ID -->
    <!-- Test ID during development: ca-app-pub-3940256099942544~3347511713 -->
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713"/>

    <!-- Required for Google UMP -->
    <meta-data android:name="com.google.android.gms.ads.flag.OPTIMIZE_INITIALIZATION" android:value="true"/>
    <meta-data android:name="com.google.android.gms.ads.flag.OPTIMIZE_AT_STARTUP" android:value="true"/>
</application>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<!-- Test ID during development: ca-app-pub-3940256099942544~1458002511 -->
<string>ca-app-pub-3940256099942544~1458002511</string>

<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to deliver personalized ads to you.</string>

<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

All official Google test unit IDs (every format) are available in-code as `AdMobTestIds.*` — no policy violations during development.

---

## Observability Wiring

```dart
AdmobKit.initialize(
  config: AdmobKitConfig(
    analytics: MyAnalyticsTracker(),   // ILRD revenue, funnel events
    diagnostics: MyDiagnosticsTracker(), // timeouts, no-fill chains, black holes
    logLevel: kReleaseMode ? AdLogLevel.none : AdLogLevel.info,
    timeouts: AdTimeoutConfig.standard,
  ),
);
```

`AdTimeoutConfig` separates policies for `fullscreen`, `inline`, and `splash`, each with Wi-Fi/cellular/ethernet/other thresholds — defaults are tuned conservative (e.g. splash: 15s Wi-Fi / 25s cellular). Supply a custom config only if your UX requires faster pass-through.

---

## AI Agent Integration Runbook

[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

A specialized agent skill ships with this package: [`skills/flutter-ads/SKILL.md`](skills/flutter-ads/SKILL.md) — API contracts, negative constraints, behavioral guarantees, and a verification checklist tuned for AI coding agents.

```bash
# Install into current project (Claude Code, Cursor, Antigravity, Copilot, ...)
npx skills add shahid0/AdmobKit-flutter

# Or globally
npx skills add shahid0/AdmobKit-flutter -g
```

**Golden prompts** for directing agents:

- **Initial setup**: *"Integrate `admob_kit_flutter` using the `flutter-ads` skill. Two-stage initialization: Stage 1 in `main.dart`, Stage 2 in `RemoteConfigService`. Startup concurrency 1. Import from `package:admob_kit_flutter/admob_kit_flutter.dart`."*
- **Splash**: *"Implement the splash with the deterministic settlement pattern: compose `AdmobKit.waitFor(splashInterstitial)` with bootstrap futures in `Future.wait`, proceed via `AdmobKit.show` `onDismissed`. Zero timers, nothing over consent."*
- **Feed native**: *"Add a native card at feed index 3 with `NativePlacement.medium` + `AdNativeView.templated`, capacity 2, zero CLS."*
- **Tabs**: *"Place ads inside an `IndexedStack` tab shell so hidden tabs defer loading until selected."*
- **Paywall**: *"Wrap the paywall in `AdPaywallGuard` intercepting hardware back and the close button."*

---

## Architecture (for contributors)

The package is a strict layered engine — presentation facades never touch the network:

```
presentation/   AdmobKit facade, AdBannerView, AdNativeView, AdPaywallGuard, config
domain/         AdPlacement types, AdPriority, timeout policies, tracker contracts
infrastructure/ EagerAdPool · TieredAdQueue (priority dispatcher) ·
                PresentationMutex (single fullscreen) · RetryScheduler ·
                ConsentCoordinator · GoogleMobileAdsDriver
```

Load pipeline: `lease/preload → TieredAdQueue.enqueue (tier + dedup + capacity) → dispatch (concurrency-limited) → EagerAdPool buffer or direct-to-waiter delivery → AdCacheEntry (TTL) → dispose`.

Run the test suite (`flutter test` in the repo root) after any change; the pool/queue/mutex invariants are all under regression coverage.

## License & Credits

Free and open source under the **[MIT License](LICENSE)**. Created and maintained by **[Shahid](https://github.com/shahid0)**. Free to use in commercial products without in-app attribution; documentation and forks must preserve the copyright notice.
