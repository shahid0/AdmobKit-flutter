# API Reference

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

Everything below is exported by that one library. For when to use each API, read [Best practices](best-practices.md); for why it behaves as it does, read [Design decisions](design-decisions.md).

## Lifecycle

### `AdmobKit.initialize`

`Future<void> initialize({AdmobKitConfig config = const AdmobKitConfig()})`

Collects consent (Google UMP, and Apple ATT on iOS), initializes the Google Mobile Ads SDK, registers the native templates, and starts the ad engine.

- Placements in `config.placements` are registered and preloaded.
- Repeated calls share the first session. Call `dispose()` before initializing with a different configuration.
- Consent denial completes normally; no ads are requested.
- Throws `ArgumentError` for a concurrency below 1 or a TTL or timeout of zero or less. A fatal SDK or platform error completes the future with that error.

### `AdmobKit.dispose`

`void dispose()`

Ends the session: cancels pending work, disposes cached ads, and releases the presentation lock. Use it for logout, account switching, or tests, not when closing a screen. Widgets dispose their own ads.

### `AdmobKit.registerPlacements`

`void registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? placementCapacities})`

Registers placements and starts preloading fullscreen, native, and fixed banner placements. Adaptive banners load when their widget lays out.

- `placementCapacities`: buffered ads per placement id (default 1).
- Allowed while initialization is still running.
- Throws `StateError` before `initialize()` or after `dispose()`, and `ArgumentError` when an id is registered again with a different configuration.

## Waiting and presenting

### `AdmobKit.show`

`void show(FullscreenPlacement placement, {VoidCallback? onDismissed, void Function(num amount, String type)? onRewardGranted, VoidCallback? onDisplayed})`

Presents a cached interstitial, rewarded, rewarded interstitial, or app-open ad.

- Never waits for a download. If no ad is ready, ads are unavailable, or another fullscreen ad owns the screen, `onDismissed` runs at once.
- A splash placement whose load is already in flight is awaited before presenting.
- `onDismissed` always runs exactly once: after the ad closes, fails, or is unavailable. Put navigation here.
- `onRewardGranted` runs when the SDK grants a reward. Grant rewards only here.
- `onDisplayed` runs when the ad appears on screen.
- Native placements are shown with `AdNativeView`, never with `show`.

### `AdmobKit.waitFor`

`Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout})`

Deterministically prepares one placement and reports whether its ad is ready.

- Waits for consent and SDK setup, requests the ad if needed, and moves it to the front of the queue.
- Returns `true` when the ad is ready, `false` when it cannot come: consent denied, offline, retries exhausted, premium user, or disposal.
- `timeout`: optional time budget, such as the length of a task the user is doing. Without it, the wait settles on its own.
- Offline it returns `false` at once; the load stays queued and resumes when the network returns.
- For a splash placement, `false` ends the splash moment: its load is dropped, so a following `show` continues immediately.
- `bannerLayout`: required for adaptive banners and rejected for every other placement.
- A ready result does not reserve the ad; another `show` or widget can still take it.

### `AdmobKit.waitForAll`

`Future<bool> waitForAll(Iterable<AdPlacement> placements, {Duration? timeout})`

Deterministically prepares a funnel step, for example every onboarding ad while the splash screen is up.

- Loads the placements in list order, ahead of background preloads.
- Returns `true` only when every placement is ready. Ads that load stay buffered for the next step's widgets and `show` calls either way.
- `timeout`: optional time budget for the whole group.
- Throws `ArgumentError` for adaptive banners, which load on layout.

### Status

| Member | Type | Meaning |
| :--- | :--- | :--- |
| `initializationState` | `AdInitializationState` | `uninitialized`, `gatheringConsent`, `initializingSdk`, `ready`, `updatingConsent`, `consentDenied`, `failed`, or `disposed` |
| `initializationStateListenable` | `ValueListenable<AdInitializationState>` | The same value, for reactive UI |
| `canRequestAds` | `bool` | Initialization finished, consent allows ads, and the user is not premium |
| `waitUntilCanRequestAds()` | `Future<bool>` | Settles when eligibility is resolved |
| `isUserPremium` | `bool` | Current result of `AdmobKitConfig.isPremium` |
| `isShowingAd` | `bool` | A fullscreen ad, including a fullscreen native ad, owns the screen |
| `isReady(placement)` | `bool` | A fresh ad is buffered now |
| `isLoading(placement)` | `bool` | A request is queued, in flight, or waiting to retry |
| `getState(placement)` | `AdPlacementState` | `unloaded`, `loading`, `ready`, or `error` |
| `watchState(placement)` | `Stream<AdPlacementState>` | State changes, for diagnosis |

`isReady`, `isLoading`, `getState`, and `watchState` take an optional `bannerLayout` for adaptive banners. They support diagnosis; use `waitFor` for decisions.

## Privacy and tools

| Member | Type | Meaning |
| :--- | :--- | :--- |
| `isPrivacyOptionsRequired()` | `Future<bool>` | Google UMP requires a privacy settings entry in your app |
| `showPrivacyOptionsForm()` | `Future<bool>` | Opens the UMP form; cached ads are discarded and reload under the new consent. Returns `false` over a fullscreen ad |
| `openAdInspector([onComplete])` | `void` | Opens Google Ad Inspector for on-device checks |
| `setNativeStyle(style, {placement})` | `Future<void>` | Restyles native ads live; see [Native ads](native-ads.md) |

## Widgets

### `AdBannerView`

`AdBannerView({Key? key, required BannerPlacement placement, double? width, bool? reserveSpace, Widget? placeholder})`

- `width`: host width. Defaults to the parent's bounded width, or the fixed banner width in an unbounded parent. Adaptive banners in an unbounded parent require it.
- `reserveSpace`: overrides `placement.sizing.reserveSpace`. When `true`, the configured height is kept before and after loading; when `false`, the host collapses until the ad has a size.
- `placeholder`: shown while loading in reserved space. Defaults to a shimmering "Loading ad" placeholder.
- Requests its first ad when visible, keeps the delivered banner for its lifetime, and sizes itself to the rendered creative.
- On a width or orientation change, an adaptive banner keeps the current ad on screen until the new size arrives.
- A fixed banner wider than its host renders nothing and makes no request.
- Throws `FlutterError` for an unbounded width without `width`.

### `AdNativeView`

`AdNativeView({Key? key, required NativePlacement placement, Widget? placeholder, bool showPlaceholder = true})`

- Needs a bounded width of at least 320 logical pixels. Inline templates size themselves to their content; fullscreen templates fill a bounded height of at least 320.
- `placeholder`: shown while loading. Defaults to a shimmering "Loading ad" placeholder; `showPlaceholder: false` hides it.
- Requests its first ad when visible, keeps the delivered ad for its lifetime, and keeps its list or page item alive when scrolled away.
- A fullscreen template owns the presentation lock only while it is measured and more than half of it is on screen. Swiping its page away releases the lock; swiping back regains it with the same ad.
- Throws `FlutterError` for invalid bounds, or when measured content needs more height than the host provides.

### `AdPaywallGuard`

`AdPaywallGuard({Key? key, required FullscreenPlacement placement, required VoidCallback onDismiss, Widget? child, Widget Function(BuildContext context, VoidCallback triggerDismiss)? builder, bool isPurchased = false})`

Routes a paywall's close button (via `builder`) and the Android back button through one exit that shows `placement`, then calls `onDismiss`.

- `isPurchased: true` or a premium user closes at once without an ad.
- The exit starts once; repeated taps or back presses are ignored.

## Placements

| Class | Format | Default priority | Extra parameters |
| :--- | :--- | :--- | :--- |
| `InterstitialPlacement` | Interstitial | `high`, or `splash` with `isSplash` | `isSplash` |
| `AppOpenPlacement` | App open | `high`, or `splash` with `isSplash` | `isSplash` |
| `RewardedPlacement` | Rewarded | `medium` | |
| `RewardedInterstitialPlacement` | Rewarded interstitial | `medium` | |
| `BannerPlacement` | Banner | `medium`, or `splash` with `isSplash` | `sizing`, `collapsible`, `isSplash` |
| `NativePlacement` | Native | `medium`, or `splash` with `isSplash` | `template`, `style`, `isSplash` |

Shared parameters:
- `androidId`, `iosId`: ad unit IDs (they contain `/`).
- `id`: unique placement id; defaults to `androidId`.
- `priority`: queue tier (`immediate`, `splash`, `high`, `medium`, `low`). Leave the default; see [Best practices](best-practices.md#2-leave-priorities-at-their-defaults).
- `loadOnce`: the placement is used once; no spare is loaded after it is shown.

### Banner sizing

| Constructor | Size | Reserves space | Loads |
| :--- | :--- | :--- | :--- |
| `BannerSizing.anchoredAdaptive()` (default) | SDK height at the host width | No | On layout |
| `BannerSizing.inlineAdaptive(maxHeight: 160)` | Host width, height up to `maxHeight` (at least 32) | Yes | On layout |
| `BannerSizing.fixed(width: 468, height: 60)` | Exact | Yes | At registration |
| `standard()`, `mediumRectangle()` / `mrec()`, `large()` / `largeBanner()`, `leaderboard()` | 320×50, 300×250, 320×100, 728×90 | Yes | At registration |

Inline and fixed constructors accept `reserveSpace`. `isFixed`, `isAdaptive`, and `isInline` describe the mode.

### Banner layout

`BannerLayout({required int width, required BannerOrientation orientation})` describes an adaptive banner's host for `waitFor` and the status methods. `BannerOrientation` is `portrait` or `landscape`.

### Collapsible banners

`BannerPlacement.collapsible({CollapsibleAnchor anchor = CollapsibleAnchor.bottom, String? id, required String androidId, required String iosId, AdPriority? priority, bool loadOnce = false})`

Requests an anchored adaptive banner that may expand as a collapsible overlay. Use `CollapsibleAnchor.top` for a top banner. The host animates height changes over 200 ms; Google's SDK owns the overlay and its collapse button. See [Google's collapsible banner guide](https://developers.google.com/admob/flutter/banner/collapsible).

### Native templates and style

`NativeAdTemplate` has 19 templates and five aliases; `NativeAdStyle` sets colors and the button radius. Both are described in [Native ads](native-ads.md).

## Configuration

`AdmobKitConfig` is passed to `initialize`.

| Field | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `placements` | `List<AdPlacement>?` | `null` | Placements registered during initialization |
| `requestConsent` | `bool` | `true` | Run Google UMP and Apple ATT before requesting ads |
| `consentTestConfig` | `ConsentTestConfig?` | `null` | Debug geography and test device IDs for UMP |
| `isPremium` | `bool Function()?` | `null` | Synchronous entitlement check; `true` suppresses all ads |
| `nativeStyle` | `NativeAdStyle` | `NativeAdStyle()` | App-wide native template style |
| `initialConcurrency` | `int` | `1` | Parallel downloads during the startup batch |
| `subsequentConcurrency` | `int` | `1` | Parallel downloads afterwards |
| `placementCapacities` | `Map<String, int>?` | `null` | Buffered ads per placement id |
| `adTtl` | `Duration` | 50 minutes | Age after which an unshown ad is replaced |
| `timeouts` | `AdTimeoutConfig` | `AdTimeoutConfig.standard` | Per-request download windows |
| `testDeviceIds` | `List<String>?` | `null` | AdMob test device IDs |
| `analytics` | `AdAnalyticsTracker?` | `null` | Revenue and lifecycle events |
| `diagnostics` | `AdDiagnosticsTracker?` | `null` | Network and retry health events |
| `logLevel` | `AdLogLevel?` | `null` | `verbose`, `info`, `warning`, `error`, or `none`. Defaults to verbose in debug and silent in release |

`ConsentTestConfig({DebugGeography debugGeography = DebugGeography.debugGeographyDisabled, List<String> testIdentifiers = const []})` simulates consent regions; `DebugGeography` is exported.

### Timeout profiles

`AdTimeoutConfig` holds an `AdTimeoutPolicy` for fullscreen, inline, and splash requests, each with Wi-Fi, cellular, ethernet, and other-network windows. These bound one download, not your `waitFor` calls.

| Profile | Fullscreen (Wi-Fi / cellular) | Splash | Inline | Use |
| :--- | :--- | :--- | :--- | :--- |
| `standard` | 30 s / 50 s | 25 s / 45 s | 20 s / 35 s | Default |
| `emergingMarkets` | 45 s / 75 s | 35 s / 65 s | 30 s / 50 s | High-latency or 2G/3G networks |
| `relaxed` | 35 s / 60 s | 30 s / 50 s | 25 s / 40 s | Large media creatives |
| `aggressive` | 15 s / 25 s | 15 s / 25 s | 10 s / 15 s | Fast, reliable networks |

## Telemetry

### `AdAnalyticsTracker`

| Callback | When |
| :--- | :--- |
| `onAdRequested(placement)` | A load starts |
| `onAdLoaded(placement, loadTime)` | An ad is ready. `loadTime` runs from the request and includes queue wait |
| `onAdFailedToLoad(placement, error, errorCode)` | A load fails for good |
| `onAdDisplayed(placement)` | A fullscreen ad appears |
| `onAdDismissed(placement)` | A fullscreen ad closes |
| `onAdClicked(placement)` | The user taps an ad |
| `onPaidEvent(placement, revenue)` | An impression earns revenue: `AdRevenueValue` with `micros`, `value`, `currencyCode`, and `precision` |

### `AdDiagnosticsTracker`

`onDiagnosticReport(AdDiagnosticReport report)` receives events of type `requested`, `loaded`, `failedToLoad`, `timeout`, `retryScheduled`, `circuitBroken`, `staleEvicted`, `blackHoleSuspected`, `displayed`, and `dismissed`. Each report carries the placement id, format, attempt, elapsed network time, AdMob error code and message, and network type.

## Test ad unit IDs

`AdMobTestIds` holds Google's official test unit IDs. Use them during development.

| Format | Android | iOS |
| :--- | :--- | :--- |
| Banner | `bannerAndroid` | `bannerIos` |
| Native | `nativeAndroid` | `nativeIos` |
| Interstitial | `interstitialAndroid` | `interstitialIos` |
| Rewarded | `rewardedAndroid` | `rewardedIos` |
| Rewarded interstitial | `rewardedInterstitialAndroid` | `rewardedInterstitialIos` |
| App open | `appOpenAndroid` | `appOpenIos` |
