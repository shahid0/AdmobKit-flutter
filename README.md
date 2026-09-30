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
4. **Template-Bound Native Dimensions** — Choose one of 20 inline layouts on the placement. `AdNativeView` reserves its catalog height: small 112dp, medium 180dp, large 360dp.

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
}
```

**2. Stage 1 — cold boot** (`main.dart`, before anything network-dependent):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = AdmobKit.initialize(
    config: AdmobKitConfig(
      initialConcurrency: 1,   // single-radio discipline on slow networks
      subsequentConcurrency: 1,
      isPremium: () => UserStore.isVip, // universal ad suppression gate
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

### Initialization readiness without polling

`canRequestAds` is a synchronous **snapshot**, not a consent-only flag. It becomes true only after UMP/ATT, SDK initialization, and native factory registration have completed, and the user is not premium. Do not use a false snapshot during startup to permanently skip an ad.

Start `initialize` once. Calls to `waitFor`, inline widgets, and `preload` made while it is running wait for that same initialization. Registrations made during startup are retained, including their capacities. No guessed delays are needed:

```dart
final boot = AdmobKit.initialize(config: yourConfig);
AdmobKit.registerPlacements([AppAds.splashInterstitial]);
final adReady = AdmobKit.waitFor(AppAds.splashInterstitial);

try {
  await boot; // SDK/factory errors propagate here; consent denial is not an error.
  if (await adReady) {
    AdmobKit.show(AppAds.splashInterstitial, onDismissed: continueNavigation);
  } else {
    continueNavigation();
  }
} catch (error) {
  // Report initialization failure and continue the application flow.
  continueNavigation();
}
```

For an eligibility decision without requesting an ad, use `await AdmobKit.waitUntilCanRequestAds()`. It waits while initialization or a privacy update is pending; false means settled consent denial, initialization failure, premium entitlement, disposal, or initialization was never started. It does not implicitly initialize the package. Eligibility does not guarantee network connectivity or ad fill; `waitFor(placement)` resolves actual ad readiness.

Observe `AdmobKit.initializationStateListenable` with `ValueListenableBuilder<AdInitializationState>` to display `gatheringConsent`, `initializingSdk`, or `updatingConsent`. Terminal states are `ready`, `consentDenied`, `failed`, and `disposed`; `uninitialized` means initialization has not been started.

The ad timeout supplied to `waitFor` starts **after** initialization/consent settles. Time spent reading a consent form does not consume the ad-loading timeout. Consent forms await real dismissal rather than a fixed timer. If the native platform never responds, the stage remains pending; `dispose()` explicitly cancels this session and releases its waiting callers.

Concurrent/repeated `initialize` calls share the first configuration and future. Use `dispose()` before changing configuration; a failed initialization can be retried. Privacy options temporarily suspend new loads, discard old buffered ads, recheck UMP eligibility after dismissal, and resume waiting requests only if allowed. `show()` remains a non-blocking cache-only presentation API; use `waitFor` first when startup settlement is required.

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
| `preload` | `Future<void> preload(AdPlacement, {BannerLayout? bannerLayout})` | Awaitable on-demand top-up. Waits for initialization/privacy settlement. |
| `leaseInlineAd` | `Future<dynamic> leaseInlineAd(InlinePlacement, {Duration? timeout})` | Package-internal. Used by `AdBannerView` / `AdNativeView` — do not call from app code. |
| `isShowingAd` | `bool get isShowingAd` | A fullscreen ad is currently on screen (gate App Open re-entry with this). |
| `isUserPremium` | `bool get isUserPremium` | Effective entitlement state. |
| `canRequestAds` | `bool get canRequestAds` | Snapshot of resolved consent + SDK/factories + non-premium entitlement. |
| `waitUntilCanRequestAds` | `Future<bool> waitUntilCanRequestAds()` | Awaits pending initialization/privacy resolution before returning eligibility. |
| `initializationState` | `AdInitializationState get initializationState` | Current initialization/privacy stage. |
| `initializationStateListenable` | `ValueListenable<AdInitializationState>` | Observable stage for initialization UI; no polling. |
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
| `NativePlacement(template: ...)` | Inline | `medium` | `splash` | Feed cards, in-content units |

All accept `priority:` to override, `loadOnce:` (one-time placements — set `true` for splash/onboarding to prevent wasteful replenishment), and `isSplash:` (routes to the dedicated splash tier + deterministic settlement on show).

### Native templates

| Templates | Height | Arrangements |
| :--- | :--- | :--- |
| `small1`–`small8` | 112dp | Compact rows with optional icon/metadata and compact or tall side CTA |
| `medium1`–`medium6` | 180dp | Two media split-cards and four icon/content cards with top or bottom CTA |
| `large1`–`large6` | 360dp | Media cards with different content and CTA positions |
| `fullscreen1`–`fullscreen5` | Fill bounded height, minimum 360dp | Fullscreen content/media/CTA compositions |

```dart
const articleAd = NativePlacement(
  id: 'article_native',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.large1,
);

// The parent supplies the width; the template owns the reserved height.
AdNativeView(placement: articleAd)
```

The default template is `medium1`. All templates require a bounded width of at
least 320 logical pixels and enough height for the selected template. Invalid
bounds fail before the widget requests an ad. There are no widget-level size or
template overrides, custom factory IDs, or legacy small/medium/big constructors.
A different template requires a distinct placement ID.

Each layout reserves a separate attribution/AdChoices strip. Missing optional
assets leave their reserved space empty; no substitute CTA or advertiser text is
invented. The SDK owns asset clicks and impressions.

These are adaptations of the upstream arrangements, using its iOS variant
ordering consistently across platforms. Sizes, asset binding and stack layouts
are adapted to this package, not pixel-identical copies. See
[third-party attribution](THIRD_PARTY_NOTICES.md).

### Fullscreen native hosts

Select a fullscreen template on a distinct placement and give the host bounded
space (at least 320 × 360 logical pixels **after** safe areas and navigation).
Fullscreen `template.height` is a minimum, not the rendered height. The example
app's fullscreen menu demonstrates all five variants with an always-available
close button outside the ad.

```dart
const fullscreenNative = NativePlacement(
  id: 'onboarding_fullscreen',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.fullscreen1,
  loadOnce: true,
);

Scaffold(
  appBar: AppBar(leading: const CloseButton()),
  body: const SafeArea(child: AdNativeView(placement: fullscreenNative)),
)
```

The existing session loads the ad normally. A loaded, active native host acquires
exclusive presentation before mounting its SDK `AdWidget`; downloads and
placeholders do not hold the lock. If an interstitial, app-open ad, or another
fullscreen native owns it, the native host waits for an ownership notification.
`AdmobKit.isShowingAd` includes this ownership. Ordinary inline templates do not
take the fullscreen lock. These templates remain native placements: mount them
with `AdNativeView`, not `AdmobKit.show`.

Visibility, TickerMode, app foreground state, and widget attachment gate
presentation. Hiding/removing the host releases ownership; a fresh retained ad
can be shown again without another request. Expired retained/waiting ads reload
before presentation. `loadOnce` still disables background replenishment, not
fresh demand after consumption.

For a `PageView` or other lazy container that keeps offscreen children active,
pass `active: pageIndex == currentPage` from the container's selection state.
`active` cannot override a hidden or ticker-disabled ancestor. Arbitrary viewport
visibility is not inferred. Keep dismissal/navigation outside the ad assets;
use safe areas and do not cover AdChoices or media controls.

Variant 3 adapts the source overlay into a dedicated bottom panel, leaving media
controls clear. Variant 4 splits the available content height evenly between
media and content/CTA. Fullscreen natives share the same live color API.
For production setup, follow Google's fullscreen native guidance for
[Android](https://developers.google.com/admob/android/native/full-screen) and
[iOS](https://developers.google.com/admob/ios/native/full-screen), including a
dedicated fullscreen ad unit.

### Native colors and live themes

All 25 native templates support `background`, `headline`,
`body`, `callToActionBackground`, and `callToActionText`. Values are unsigned
ARGB integers (`0xAARRGGBB`); Flutter colors can use `color.toARGB32()`.
The `body` slot also colors optional advertiser, rating and price text. Attribution
and SDK-owned AdChoices styling are not overridden.

```dart
const feedNative = NativePlacement(
  template: NativeAdTemplate.medium1,
  id: 'feed',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  colors: NativeAdColors(callToActionBackground: 0xff6750a4),
);

await AdmobKit.initialize(config: const AdmobKitConfig(
  placements: [feedNative],
  nativeColors: NativeAdColors(background: 0xff141416, headline: 0xffffffff),
));

// Apply a new global theme to pending, cached, and displayed native ads.
await AdmobKit.setNativeColors(const NativeAdColors(
  background: 0xfffafafa,
  headline: 0xff161616,
  body: 0xff333333,
));

// Replace this placement's overrides (not a merge with its previous overrides).
await AdmobKit.setNativeColors(const NativeAdColors(
  callToActionBackground: 0xff2457c5,
  callToActionText: 0xffffffff,
), placement: feedNative);

// Remove its overrides, including the initial placement colors.
await AdmobKit.setNativeColors(const NativeAdColors(), placement: feedNative);
```

Precedence is per-placement overrides → global colors → template defaults.
Null fields inherit; an empty global palette restores template defaults wherever
there is no placement override. Updates preserve the loaded ad, its age, layout,
and click regions. They do not cause additional ad requests. Await the update:
platform failures are reported through its future. The desired colors are retained
and included in the next update/request; there is no hidden retry loop. Call
`initialize()` before setting colors; updates do not wait for consent or request ads.

An inactive native host retains its ad, but checks the original load age before
showing it again. Expired ads are disposed and replaced on reactivation.

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
      ? const AdNativeView(placement: AppAds.feedNative)
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

For a custom retained-page host, both ad widgets also accept `active: currentIndex == pageIndex`.
This is an additional gate: `active: true` never overrides an inactive `TickerMode` or `Visibility` ancestor.
Inactive hosts retain their leased ad but unmount its platform view; reactivation reuses the lease without another request.
Disposal, privacy updates, and failed/denied initialization discard the host's lease.

### Adaptive banners

`BannerPlacement` defaults to `BannerSizing.anchoredAdaptive()`. `AdBannerView` takes the available logical width from its parent and uses the SDK-selected height. Give the parent a bounded width, or supply `width:` when the parent is horizontally unbounded. The former fixed `height:` option is removed.

For a scrolling feed:

```dart
const feedBanner = BannerPlacement(
  id: 'feed_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
);
const AdBannerView(placement: feedBanner);
```

Inline banners reserve `maxHeight` and center the creative at the actual size reported by the SDK. Anchored banners occupy zero height until the SDK resolves and loads the ad; they do not promise zero layout shift during that initial resolution. No fixed-size fallback is used when sizing fails. Refresh remains SDK-managed, including render-size updates.

Registration retains banner configuration but cannot preload a banner until its layout is known. Widgets supply the layout automatically. For explicit `preload`, `waitFor`, `isReady`, `isLoading`, `getState`, or `watchState`, pass `bannerLayout:`:

```dart
const layout = BannerLayout(width: 360, orientation: BannerOrientation.portrait);
final ready = await AdmobKit.waitFor(feedBanner, bannerLayout: layout);
```

Use the host's actual logical width and device orientation. Width/orientation changes create distinct requests; readiness for one size never means another size is ready. Buffer capacity and `loadOnce` remain placement-scoped, and a placement ID cannot be reused with different units, sizing, or policy during a session. Flutter 3.41 or newer is required.

### One-time screens and `loadOnce`

`loadOnce: true` disables **background replenishment after consumption** for the current pool session. It is not a one-impression limit or a permanent per-install flag. Remaining cached and in-flight ads stay usable. A later inline widget mounting with the same placement can request a fresh ad when its buffer is empty, without refilling the buffer afterward.

`preload` does not restart background loading after consumption. `waitFor` can await remaining requests or report readiness of buffered ads; it does not replenish an exhausted `loadOnce` placement. Inline widget demand is what starts a fresh request.

Register first-run-only placements conditionally: Stage 2 primes registered placements even if the user never reaches their screens.

```dart
// ❌ Wrong: onboarding exists only for new installs, but its placement is
// registered unconditionally. Second-launch users pay for a load they'll
// never see.
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

The placement list should mirror what can actually be shown in this session, not the app's full static inventory. `registerPlacements` is callable multiple times, so register a screen's placement when (or just before) that screen becomes reachable. Mounting an inline ad widget can also request an ad directly.

### Slow splash on a bad connection

`isSplash: true` + `loadOnce: true`. If the ad is already in memory at show time → 0ms display. If it's still downloading, the splash deterministically awaits readiness, failure, or timeout without holding the presentation lock. Duplicate show requests for that pending placement are rejected. Once ready, it acquires the lock immediately before presentation; if another ad is then on screen, `onDismissed` runs and the cached splash ad remains available.

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

### Requirements and example gallery

- Flutter >=3.41 with Dart >=3.11.5, matching this package's declared constraints.
- Android minSdk 24, compileSdk 36, Java 17. The native SDK dependency is aligned with `google_mobile_ads` 9.1.0: Google Mobile Ads 25.4.0.
- iOS deployment target 13.0 or later. The current Flutter SDK dependency uses Google Mobile Ads `~>13.7`; its minimum Xcode version is 26.2. See Google's [iOS release notes](https://developers.google.com/admob/ios/rel-notes). Installed Xcode/simulator tooling can impose additional local build constraints.

Run the app in `example/` and open **Ad gallery** from the home toolbar. Browse all 25 native templates without preloading the inventory; opening a preview requests only that placement. The palette menu applies live colors or resets inheritance without loading another ad. The two banner demos expose width changes and use SDK-resolved heights. Use Google test IDs for device checks, including rotation, large text, missing assets, AdChoices/video controls, navigation and background/resume.

The automated suite checks transport, lifecycle and layout contracts. Real SDK rendering and physical-device accessibility checks are still required; passing unit/widget tests is not a substitute.

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

A specialized agent skill ships with this package: [`skills/flutter-ads/SKILL.md`](skills/flutter-ads/SKILL.md) — a concise integration runbook with workflow, decision table, and verification checklist, backed by on-demand reference files (`reference/api.md` for the full API surface, `reference/patterns.md` for working code).

```bash
# Install into current project (Claude Code, Cursor, Antigravity, Copilot, ...)
npx skills add shahid0/AdmobKit-flutter

# Or globally
npx skills add shahid0/AdmobKit-flutter -g
```

**Golden prompts** for directing agents:

- **Initial setup**: *"Integrate `admob_kit_flutter` using the `flutter-ads` skill. Two-stage initialization: Stage 1 in `main.dart`, Stage 2 in `RemoteConfigService`. Startup concurrency 1. Import from `package:admob_kit_flutter/admob_kit_flutter.dart`."*
- **Splash**: *"Implement the splash with the deterministic settlement pattern: compose `AdmobKit.waitFor(splashInterstitial)` with bootstrap futures in `Future.wait`, proceed via `AdmobKit.show` `onDismissed`. Zero timers, nothing over consent."*
- **Feed native**: *"Add a native card at feed index 3 with `NativePlacement(template: NativeAdTemplate.medium1)` + `AdNativeView`, capacity 2, zero CLS."*
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
