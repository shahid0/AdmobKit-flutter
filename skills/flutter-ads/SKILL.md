---
name: flutter-ads
description: >-
  Architect and integrate production-grade mobile ads in Flutter using admob_kit_flutter
  (facade: AdmobKit). Enforces deterministic settlement (waitFor), two-stage initialization,
  UMP consent gating, priority-tiered preloading with demand-based leasing, template-bound
  native dimensions, adaptive network timeouts, hardware-back paywall guards, and
  layout-stable zero-CLS containers for IndexedStack and route-based tab structures.
---

# AdmobKit (`admob_kit_flutter`) — Agent Integration Runbook

**Package:** `admob_kit_flutter` · **Facade:** `AdmobKit` · **Widgets:** `AdBannerView`, `AdNativeView`, `AdPaywallGuard`

**The one import that always works:**

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

**Always emit `AdmobKit` and the import above in generated code.**

Found a bug, unexpected behavior, or an edge case the docs don't cover? **Do not patch around it** (no timers, delays, or hand-rolled ad instantiation as workarounds) — those "band-aid" fixes reintroduce the exact races this package eliminates. Instead, stop and tell the user to [open a GitHub issue](https://github.com/shahid0/AdmobKit-flutter/issues/new/choose) with the placement config and logs, and keep the integration on the documented contracts until it's resolved.

This skill is self-contained: it carries the API contracts, behavioral guarantees, negative constraints, and verification gates an agent needs. Canonical long-form recipes live in the package [README](../../README.md); this file wins on any conflict.

---

## 1. The Core Mental Model (4 Laws)

1. **The 0ms Show Contract**: `AdmobKit.show(placement, onDismissed: ...)` is strictly non-blocking. Ad in memory → displays instantly. Unready/expired/offline → `onDismissed` fires immediately. Never stall navigation.
2. **Deterministic Settlement**: Never guess ad readiness with `Timer()`/`Future.delayed()`. `await AdmobKit.waitFor(placement)` → `bool` (compose in `Future.wait`).
3. **Immediate-Display Priority**: The visible screen's ad wins the network. `waitFor` and widget leases auto-promote their placement to the `immediate` tier, preempting background preloads.
4. **Template-Bound Dimensions**: Native sizes are owned by native layouts (`small` 74dp, `medium` 130dp, `big` 300dp). Never guess pixel heights — read `template.height`.

---

## 2. API Surface (emit exactly these names)

### Facade

| Call | Returns | Contract |
| :--- | :--- | :--- |
| `AdmobKit.initialize(config: AdmobKitConfig(...))` | `Future<void>` | **Stage 1** in `main()`: UMP/ATT consent + GMA SDK. Call once. |
| `AdmobKit.registerPlacements(list, {placementCapacities})` | `void` | **Stage 2** when IDs resolve. Callable repeatedly. Register conditionally for one-time screens (see loadOnce trap). |
| `AdmobKit.show(placement, onDismissed:, onDisplayed:, onRewardGranted:)` | `void` | Fullscreen only (compile-time enforced). 0ms or pass-through. |
| `AdmobKit.waitFor(placement)` | `Future<bool>` | `true` ready · `false` failed/timeout/premium. Promotes to immediate tier. |
| `AdmobKit.isReady(placement)` / `isLoading(placement)` | `bool` | Buffer snapshot / in-flight download. |
| `AdmobKit.getState(placement)` | `AdPlacementState` | `unloaded · loading · ready · error` |
| `AdmobKit.watchState(placement)` | `Stream<AdPlacementState>` | Reactive transitions for custom loading UIs. |
| `AdmobKit.preload(placement)` | `void` | Manual top-up; no-ops if capacity already satisfied. |
| `AdmobKit.isShowingAd` | `bool` | Fullscreen on screen — **gate App Open re-entry with this**. |
| `AdmobKit.showPrivacyOptionsForm()` | `Future<bool>` | GDPR settings (wire in app Settings). |
| `AdmobKit.openAdInspector(onComplete)` | `void` | QA: native Ad Inspector. |

`leaseInlineAd` is package-internal (the widgets call it). **Never call it from app code.**

### Placements (all `const`, declare once in a `SampleAds`-style class)

```dart
InterstitialPlacement(id:, androidId:, iosId:, priority:, loadOnce:, isSplash:)
AppOpenPlacement(...)  ·  RewardedPlacement(...)  ·  RewardedInterstitialPlacement(...)
BannerPlacement(...)   ·  NativePlacement.big(...) / .medium(...) / .small(...)
```

- Defaults: interstitial/app-open → `AdPriority.high` (`splash` if `isSplash`), banner/native/rewarded → `medium`. Override with `priority:`.
- `loadOnce: true` for one-time placements (splash, onboarding) — prevents auto-replenishment after consumption.
- Test unit IDs: `AdMobTestIds.interstitialAndroid`, `.bannerIos`, `.nativeAndroid`, etc. Use them in dev — production IDs trigger policy violations.

### `AdmobKitConfig` (key fields)

`requestConsent (true)` · `isPremium (() => bool)` · `initialConcurrency (1)` · `subsequentConcurrency (1)` · `placementCapacities (Map<String,int>)` · `adTtl (50min)` · `analytics` · `diagnostics` · `logLevel` · `timeouts` · `testDeviceIds` · `consentTestConfig` · `initializeNativeGma (true)`

### State machine

```
unloaded → loading → ready → (leased/consumed) → unloaded
                └→ error (fatal AdMob code / circuit breaker)
```

---

## 3. Behavioral Guarantees (what the engine does so you don't have to)

| Scenario | Engine behavior | UI expectation |
| :--- | :--- | :--- |
| Ad buffered at show time | 0ms display | — |
| Buffer empty at fullscreen show | `onDismissed` fires immediately (flow continues) | Don't block navigation |
| Splash still downloading at show | Mutex held; settles deterministically: shows when ready, or passes through on fail/timeout | No blank hang, no dropped splash |
| Concurrent fullscreen triggers | Second is rejected; its `onDismissed` fires at once | Never two fullscreen ads |
| AdMob no-fill / network error | Backoff retry (≤4, code 1 fatal); inline waiters settle fast with `null` | Placeholder → empty state, never infinite spinner |
| Offline cold start | `waitFor` → `false` on timeout; loads auto-resume on reconnect | Render empty/retry state |
| Tab reactivation after offline failure | Failed-attempt flag resets on deactivation; lease retries | Tab recovers after reconnect |
| Two widgets, same placement | Each receives its own exclusive ad instance | No `AdWidget` crash — ever |
| Hidden `IndexedStack` tab | Load deferred until tab visible | Hidden tabs cost zero network |
| Premium user | Zero traffic: preloads skipped, `show` passes through, widgets collapse to `SizedBox.shrink` | Zero reserved space |
| Ad exceeds `adTtl` (50 min) | Evicted from buffer, reloaded on next use | Transparent |

---

## 4. Invariant Negative Constraints

Integration rules — violating any of these is a bug:

- ❌ **DO NOT use `Timer`/`Future.delayed` for ad readiness or splash navigation.** Use `await AdmobKit.waitFor(...)`.
- ❌ **DO NOT work around engine behavior with band-aid fixes.** If something misbehaves, surface it: have the user file a GitHub issue instead of stacking timers/delays/manual instantiation on top. Workarounds hide real bugs and reintroduce races.
- ❌ **DO NOT register one-time-screen placements unconditionally.** `loadOnce: true` consumes the placement permanently per install — see the registration rule below.
- ❌ **DO NOT fire ads before or over the UMP consent form.** Consent resolution precedes display and startup navigation.
- ❌ **DO NOT emit any other facade name or import path.** The package is `admob_kit_flutter`, the facade is `AdmobKit` — no aliases exist.
- ❌ **DO NOT call `leaseInlineAd` from app code** — use `AdNativeView` / `AdBannerView`; they own the lease lifecycle.
- ❌ **DO NOT guess or hardcode native container heights** (`height: 300`). Bind `template.height` / template constructors.
- ❌ **DO NOT attach paywall exit interstitials solely to the UI close button.** `AdPaywallGuard` must intercept hardware back / edge swipe too.
- ❌ **DO NOT delay `initialize()` behind Remote Config.** Two-stage boot: Stage 1 in `main()`, Stage 2 via `registerPlacements` when IDs resolve.
- ❌ **DO NOT fire App Open ads when resuming from a fullscreen ad or over an open modal/paywall.** Check `AdmobKit.isShowingAd` first.
- ❌ **DO NOT set `loadOnce: false` on one-time placements** (splash, onboarding).
- ❌ **DO NOT set `placementCapacities` speculatively.** Default depth 1 is correct for almost every app — only set it when two widgets with the same placement are mounted simultaneously, and set it to exactly that count (see below).
- ❌ **DO NOT mount two `AdNativeView`s for the same placement without registering capacity ≥ 2.** (Engine still guarantees distinct instances; capacity keeps the buffer warm.)
- ❌ **DO NOT hand-roll `NativeAd`/`BannerAd` instantiation or `AdWidget` mounting.** The widgets encapsulate leasing, disposal, and premium collapse.
- ❌ **DO NOT introduce arbitrary spinners with no exit.** Every async path settles; render empty states on `error`/timeout.

Package-maintainer rules (only when modifying this package, not when integrating it):

- ❌ Do not add app-UI dependencies to the root package (`google_mobile_ads`, `connectivity_plus` only; app packages go in `example/pubspec.yaml`).
- ❌ Do not write fluff comments or step-banner comments; code stays self-explanatory.

### The one-time-screen registration rule (loadOnce trap)

`loadOnce: true` marks a placement consumed **permanently per install**. That's correct for splash/onboarding — but it changes how you register:

> **A screen that exists only for first-run users must NOT have its placement registered unconditionally.** Registered placements are primed at Stage 2 whether or not the user ever reaches the screen, and a skip-path (existing account sign-in) leaves the placement consumed-but-unshown forever.

```dart
// ❌ onboarding exists only for new installs — unconditional registration wastes
// a load on every install and leaves phantom consumed state on skips.
AdmobKit.registerPlacements([SampleAds.onboardingNative]);

// ✅ The caller knows the routing context — register conditionally.
AdmobKit.registerPlacements([
  SampleAds.splashInterstitial,   // shown every launch → fine
  SampleAds.feedNative,
  if (isFirstLaunch) SampleAds.onboardingNative,
]);
```

Rule: **the placement list mirrors what can actually be *shown* on this install**, not the app's full static inventory. Never registered = never loaded = zero waste. For recurring features that come and go (a settings submenu with a rewarded ad), either register lazily right before the screen becomes reachable, or use `loadOnce: false` so consumption doesn't permanently retire the placement.

---

## 5. Priority & Capacity Model (how loads are scheduled)

Five-tier dispatcher, lower rank drains first; inline loads before fullscreen within a tier:

| Tier | Rank | Assigned to | How |
| :--- | :--- | :--- | :--- |
| `splash` | 0 | Cold-start placements | `isSplash: true` |
| `immediate` | 1 | The visible screen's ads | **Automatic** via `waitFor`/lease promotion |
| `high` | 2 | Onboarding, main navigation | Default for non-splash interstitial/app-open |
| `medium` | 3 | Recurring in-app placements | Default for banner/native/rewarded |
| `low` | 4 | Background funnels | Explicit `priority: AdPriority.low` |

- **Fullscreen dedup:** two preloads for the same fullscreen placement merge into one request.
- **Inline leases are exclusive:** one ad object per widget, always.
- **Capacity — leave it at the default.** Depth 1 is correct for almost every app. `placementCapacities: {'id': n}` exists only when **n widgets with the same placement are mounted simultaneously** (e.g. two feed natives at once). Speculative depths hold expiring ads (wasted requests, lower show rate, more RAM) and can *increase* empty-buffer odds. Set only what a real screen demands; omit everywhere else.
- **Concurrency:** keep `initial/subsequentConcurrency = 1` unless measurement proves parallel loads safe on cellular.

---

## 6. Decision Tree — What Do I Mount Where?

- Fullscreen at a transition (splash, exit, interval, between levels) → **`AdmobKit.show(placement, onDismissed: …)`** · splash/onboarding get `isSplash: true, loadOnce: true`.
- Banner in an app shell (below nav bar / above content) → **`AdBannerView(placement: …)`**.
- In-content card matching your design system → **`AdNativeView.templated(placement:, template:)`** in a pre-sized `Container(height: template.height)`; multiple simultaneously visible with the same placement → set `placementCapacities` to exactly the visible count (rare — default 1 otherwise).
- Unlock feature / bonus → **`RewardedPlacement`** + `onRewardGranted`.
- Natural-break fullscreen → `RewardedInterstitialPlacement`.
- Cold/resume branding → `AppOpenPlacement` gated by `!AdmobKit.isShowingAd`.
- Paywall with exit ad → wrap screen in **`AdPaywallGuard(placement:, onDismiss:, builder:)`**.
- Ads inside tabs → `IndexedStack` works as-is; `TabBarView`/`PageView` pages need explicit `TickerMode(enabled: i == current)` or `Visibility(visible: i == current)`.
- User upgraded to VIP → nothing to change; `isPremium` callback suppresses everything.

**Which observability dependency?**

- Revenue/LTV/funnels (Firebase, AppsFlyer, Adjust) → implement **`AdAnalyticsTracker`** (`onPaidEvent` carries `AdRevenueValue`: micros + currency + precision).
- Engineering health (Sentry, Crashlytics, Datadog) → implement **`AdDiagnosticsTracker`** (`timeout`, `circuitBroken`, `blackHoleSuspected`, `staleEvicted` events).
- Revenue-targeting production app → wire **both**; pre-revenue/QA → diagnostics only; neither → rely on `AdLogLevel`.

---

## 7. Canonical Scaffolds

Skeletons only — the README holds the full versions with production detail.

**Two-stage boot:**

```dart
// main.dart — Stage 1
await AdmobKit.initialize(config: const AdmobKitConfig(
  initialConcurrency: 1, subsequentConcurrency: 1,
  isPremium: () => UserStore.isVip,
));

// remote_config_service.dart — Stage 2
// Placement list mirrors what can actually be SHOWN on this install —
// see "the loadOnce trap" above. No placementCapacities needed here.
AdmobKit.registerPlacements([SampleAds.splashInterstitial, SampleAds.feedNative]);
```

**Deterministic splash:**

```dart
await Future.wait([
  FirebaseRemoteConfig.instance.fetchAndActivate(),
  AuthService.instance.restoreSession(),
  AdmobKit.waitFor(SampleAds.splashInterstitial),
]);
if (!context.mounted) return;
AdmobKit.show(SampleAds.splashInterstitial,
    onDismissed: () => Navigator.pushReplacementNamed(context, '/home'));
```

**Zero-CLS native card:**

```dart
Container(
  height: NativeAdTemplate.medium.height,
  clipBehavior: Clip.antiAlias,
  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
  child: AdNativeView.templated(placement: SampleAds.feedNative, template: NativeAdTemplate.medium),
)
```

**Paywall guard:**

```dart
AdPaywallGuard(
  placement: SampleAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(leading: IconButton(icon: const Icon(Icons.close), onPressed: triggerDismiss)),
    body: PaywallContent(),
  ),
)
```

---

## 8. Golden Developer Prompts

- **Setup**: *"Integrate `admob_kit_flutter` per the `flutter-ads` skill. Import `package:admob_kit_flutter/admob_kit_flutter.dart`. Two-stage init: Stage 1 `main.dart`, Stage 2 `RemoteConfigService`, concurrency 1."*
- **Splash**: *"Deterministic settlement: `AdmobKit.waitFor(splashInterstitial)` composed with bootstrap futures, proceed via `AdmobKit.show`. Zero timers, nothing over consent."*
- **Feed native**: *"Native card at feed index 3 — `NativePlacement.medium`, `AdNativeView.templated`, zero CLS. Only set `placementCapacities: {'feed_native': 2}` if two cards render simultaneously."*
- **Tabs**: *"Ads in an `IndexedStack` shell; hidden tabs defer loading until selected."*
- **Paywall**: *"`AdPaywallGuard` on the paywall intercepting hardware back and the close button."*

---

## 9. Verification Checklist (complete before finishing any ad task)

1. `flutter analyze` — 0 issues.
2. Single import: `package:admob_kit_flutter/admob_kit_flutter.dart`; facade spelled `AdmobKit` everywhere.
3. No `Timer`/`Future.delayed` for ad readiness; `waitFor` used and its `bool` result handled.
4. Stage 1 in `main()`, Stage 2 after Remote Config; nothing displayed before consent resolves.
5. Native containers bound to `template.height`; zero guessed pixel sizes.
6. Multi-widget placements have matching `placementCapacities` entries.
7. Tab-hosted ads: deferral verified (`IndexedStack` native, or explicit `TickerMode`/`Visibility` for `TabBarView`/`PageView`).
8. Paywall guarded against hardware back **and** close button.
9. One-time placements declare `loadOnce: true`; App Open gated by `isShowingAd`.
10. Every async ad path renders a terminal UI state (ad, empty, or retry) — no infinite spinners.
11. Manual smoke test with `AdMobTestIds` passed on device/emulator.
