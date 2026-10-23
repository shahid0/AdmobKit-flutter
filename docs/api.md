# Public API Reference

Import the public library into your Flutter application:

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

The package manages ad loading, warm memory caching, retries, and presentation safety.
Your application manages navigation, user rewards, screen reachability, purchase state, and display frequency.
For complete implementation sequences, read [Use cases](recipes.md).

## Lifecycle and Initialization

### `AdmobKit.initialize`

`Future<void> AdmobKit.initialize({AdmobKitConfig config = const AdmobKitConfig()})`

Initializes consent, native SDK drivers, native template factories, and the background ad engine.

- **Parameters**:
  - `config`: Optional configuration object specifying timeouts, concurrency, and callbacks.
- **Behavior**:
  - Runs Google UMP consent and Apple ATT permission requests when `config.requestConsent` is `true`.
  - Initializes Google Mobile Ads SDK and registers native ad template factories.
  - Primes initial non-banner placements specified in `config.placements`.
  - Repeated calls return the active session and retain the original configuration.
  - To apply a new configuration, call `AdmobKit.dispose()` before you call `initialize()` again.
  - A consent denial completes initialization without throwing an exception.
  - If a fatal SDK or platform error occurs, the returned future completes with that error.

### `AdmobKit.dispose`

`void AdmobKit.dispose()`

Disposes the active ad session, cancels running background tasks, and evicts all cached ads.

- Call this method only during user logout, account switching, or app shutdown.
- Do not call this method when you close individual screens.
- Widgets dispose their own leased ad instances automatically.

## Placement Registration

### `AdmobKit.registerPlacements`

`void AdmobKit.registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? placementCapacities})`

Registers ad placements and starts eligible background preloading.

- **Parameters**:
  - `placements`: Collection of placement configurations to register.
  - `placementCapacities`: Optional map from placement identifiers to target buffer capacities (defaults to 1).
- **Behavior**:
  - Starts background preloading for registered fullscreen, native, and fixed banner placements.
  - Accepts calls while initialization is still in progress.
  - Throws `StateError` if called before `initialize()` or after `dispose()`.
  - Throws `ArgumentError` if you re-register an existing identifier with different configuration properties.
  - Skips adaptive banner placements. Their size depends on the measured width and orientation, so each `AdBannerView` loads one when it lays out.

## Presentation and Waits

### `AdmobKit.show`

`void AdmobKit.show(FullscreenPlacement placement, {VoidCallback? onDismissed, void Function(num amount, String type)? onRewardGranted, VoidCallback? onDisplayed})`

Presents a cached fullscreen ad immediately without waiting for a network download.

- **Parameters**:
  - `placement`: The fullscreen placement to present (`InterstitialPlacement`, `RewardedPlacement`, `RewardedInterstitialPlacement`, or `AppOpenPlacement`).
  - `onDismissed`: Callback executed when the ad closes, fails, or skips. Place navigation logic here.
  - `onRewardGranted`: Callback executed when the SDK grants a user reward.
  - `onDisplayed`: Optional callback executed when the SDK renders the ad on screen.
- **Behavior**:
  - If an ad is ready in the warm cache, presents the ad immediately.
  - If no ad is ready, or if ads are blocked, executes `onDismissed` at once (0ms wait time).
  - Never call `show()` for native placements; native ads must mount using `AdNativeView`.
  - Grant user rewards exclusively inside `onRewardGranted`.
  - Never unlock user rewards inside `onDismissed`.

### `AdmobKit.waitFor`

`Future<bool> AdmobKit.waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout})`

Deterministically awaits an ad placement until it becomes ready, fails, or times out.

- **Parameters**:
  - `placement`: The ad placement to prepare.
  - `timeout`: Maximum wait duration applied to the ad request (defaults to configured network timeout).
  - `bannerLayout`: Required for adaptive banners. Omit it for fixed banners and other formats; passing it throws `ArgumentError`.
- **Returns**:
  - `true`: A fresh ad is ready in the memory cache.
  - `false`: Consent denial, network failure, timeout, premium user, or disposal.
- **Behavior**:
  - Waits for pending consent and SDK initialization before it starts the ad timer.
  - Returns `false` at once while the device is offline. Non-splash requests stay queued and load when the network returns.
  - For a splash placement, a `false` result ends the splash moment: its load is dropped, so a following `show` continues immediately instead of waiting again.
  - Promotes the placement to immediate queue priority.
  - Does not guarantee that `show()` will present an ad later if another request consumes it first.

## Declarative Widgets

### `AdBannerView`

`AdBannerView({required BannerPlacement placement, double? width, bool? reserveSpace, Widget? placeholder})`

Embeds an adaptive or fixed Google AdMob banner into your Flutter widget tree.

- **Parameters**:
  - `placement`: The `BannerPlacement` configuration.
  - `width`: Available host width. Defaults to the parent's bounded width. In an unbounded parent, fixed banners use `sizing.fixedWidth`; adaptive banners require explicit `width`.
  - `reserveSpace`: Optional override of `placement.sizing.reserveSpace`. `true` reserves `maxHeight` or `fixedHeight`; `false` collapses until the ad has render dimensions, then uses its actual height.
  - `placeholder`: Optional widget displayed while loading when space is reserved.
- **Behavior**:
  - Calculates adaptive banner height automatically from available width and orientation.
  - Inline adaptive and fixed banners reserve their configured height by default, keeping the loaded creative centered at its actual size.
  - Fixed banners request exact dimensions and are centered when the host is wider. A host narrower than the fixed width renders nothing and requests nothing.
  - Fixed banners take the ad preloaded by `registerPlacements()` when one is ready, whatever the host width. Width and orientation changes do not reload them.
  - Adaptive banners request a new size when the width or orientation changes, and keep the current banner on screen until it arrives. A current banner wider than the new host is hidden.
  - Throws `FlutterError` for adaptive banners within unbounded width without explicit `width`.

### `AdNativeView`

`AdNativeView({required NativePlacement placement, Widget? placeholder, bool showPlaceholder = true})`

Embeds a native template ad into your Flutter widget tree.

- **Parameters**:
  - `placement`: The `NativePlacement` configuration.
  - `placeholder`: Custom widget rendered while loading.
  - `showPlaceholder`: Whether to display a placeholder while loading (defaults to `true`).
- **Behavior**:
  - Requires bounded width of at least 320 logical pixels.
  - Height adapts to actual creative text and media dimensions.
  - Leases an ad instance exclusively; disposes the instance cleanly when unmounted.
  - Throws `FlutterError` if horizontal constraints are unbounded or less than 320 logical pixels.

### `AdPaywallGuard`

`AdPaywallGuard({required FullscreenPlacement placement, required VoidCallback onDismiss, Widget? child, Widget Function(BuildContext, VoidCallback close)? builder, bool isPurchased = false})`

Guards modal screen dismissals and Android hardware back navigation with a fullscreen ad.

- **Parameters**:
  - `placement`: Fullscreen placement to show when the user exits without purchasing.
  - `onDismiss`: Callback executed when the screen must close.
  - `child`: Static child widget tree.
  - `builder`: Builder function providing the dismiss callback to custom close buttons.
  - `isPurchased`: Whether the user completed a purchase. If `true`, bypasses the ad immediately.

## Placement Specifications

### Placement Classes

| Class | Supported Format | Default Priority | Special Properties |
| :--- | :--- | :--- | :--- |
| `InterstitialPlacement` | Interstitial | `high` (or `splash`) | `isSplash` |
| `RewardedPlacement` | Rewarded Video | `medium` | None |
| `RewardedInterstitialPlacement` | Rewarded Interstitial | `medium` | None |
| `AppOpenPlacement` | App Open | `high` (or `splash`) | `isSplash` |
| `BannerPlacement` | Adaptive or Fixed Banner | `medium` (or `splash`) | `sizing`, `collapsible`, `isSplash` |
| `NativePlacement` | Native Template | `medium` (or `splash`) | `template`, `style`, `isSplash` |

### Common Placement Parameters

All placement constructors accept these parameters:

- `id`: Unique string identifier for this placement.
- `androidId`: AdMob ad unit identifier for Android.
- `iosId`: AdMob ad unit identifier for iOS.
- `priority`: Initial queue priority tier (`immediate`, `splash`, `high`, `medium`, or `low`).
- `loadOnce`: If `true`, stops background preloading after first ad consumption (defaults to `false`).

### Banner Sizing Modes

- `const BannerSizing.anchoredAdaptive()`: SDK-calculated height; `reserveSpace` is `false`.
- `const BannerSizing.inlineAdaptive({required int maxHeight, bool reserveSpace = true})`: Adaptive width and creative height up to `maxHeight` (minimum 32 logical pixels).
- `const BannerSizing.fixed({required int width, required int height, bool reserveSpace = true})`: Exact positive dimensions in logical pixels, without adaptive calculations.
- Fixed convenience constructors (each accepts `bool reserveSpace = true`): `standard()` (320×50), `mediumRectangle()` or `mrec()` (300×250), `large()` or `largeBanner()` (320×100), and `leaderboard()` (728×90, for tablets).

`maxHeight` is non-null only for inline adaptive sizing. `fixedWidth` and `fixedHeight` are non-null only for fixed sizing. `isFixed`, `isAdaptive`, and `isInline` identify the mode; `isInline` identifies inline adaptive sizing specifically. Equality includes dimensions and `reserveSpace`.

With `reserveSpace: false` on the sizing policy or widget, loading takes zero height and no placeholder is rendered. Once loaded, the host uses the actual creative height. With reservation enabled, the host keeps the configured height before and after loading.

### Collapsible Banners

`const BannerPlacement.collapsible({CollapsibleAnchor anchor = CollapsibleAnchor.bottom, String? id, required String androidId, required String iosId, AdPriority? priority, bool loadOnce = false})`

Requests an anchored adaptive banner with a native collapsible overlay. Use
`CollapsibleAnchor.top` at the top of the screen or `CollapsibleAnchor.bottom`
at the bottom. The default `BannerPlacement` constructor also accepts
`collapsible: CollapsibleAnchor.bottom`; fixed and inline adaptive sizing reject
this option. `isCollapsible` identifies the request policy, rather than whether
the SDK filled the request with a collapsible creative.

The driver reads the platform size after loading and accepts expanded heights.
The host animates reported render-height changes over 200 ms. The Google SDK
manages the expanded overlay and its collapse button; its Flutter listener does
not expose a collapse-button size event. Native overlay behavior therefore
requires device verification. See [Google's collapsible banner guide](https://developers.google.com/admob/flutter/banner/collapsible).

## Dynamic Native Styling

Update colors and corner radius on built-in native templates without reloading ads:

`Future<void> AdmobKit.setNativeStyle(NativeAdStyle style, {NativePlacement? placement})`

- **Parameters**:
  - `style`: Visual styling properties (background, text colors, and CTA corner radius).
  - `placement`: Optional placement target. Omit to update global appearance.

### `NativeAdStyle` Properties

Colors must be 32-bit unsigned ARGB integers (`0xAARRGGBB`):

- `background`: Container background color.
- `headline`: Title text color.
- `body`: Body text and metadata color.
- `callToActionBackground`: Button background color.
- `callToActionText`: Button text color.
- `callToActionCornerRadius`: Button radius in logical pixels (defaults to 8).

Use `const NativeAdStyle()` to reset a scope to inherited defaults.

## Configuration Options

Configure engine behavior during `AdmobKit.initialize()`:

```dart
Future<void> configureEngine() async {
  await AdmobKit.initialize(
    config: const AdmobKitConfig(
      initialConcurrency: 1,
      subsequentConcurrency: 1,
      adTtl: Duration(minutes: 50),
      timeouts: AdTimeoutConfig.standard,
    ),
  );
}
```

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `placements` | `List<AdPlacement>?` | `null` | Initial placements to register and prime at startup |
| `requestConsent` | `bool` | `true` | Automates Google UMP and iOS ATT consent collection |
| `consentTestConfig` | `ConsentTestConfig?` | `null` | Test geography and device identifiers for UMP testing |
| `isPremium` | `bool Function()?` | `null` | Universal entitlement check. When `true`, suppresses all ads |
| `nativeStyle` | `NativeAdStyle` | `const NativeAdStyle()` | Global styling overrides for native templates |
| `initialConcurrency` | `int` | `1` | Maximum parallel downloads during app startup |
| `subsequentConcurrency` | `int` | `1` | Maximum parallel downloads during background preloads |
| `placementCapacities` | `Map<String, int>?` | `null` | Target buffer depth per placement identifier |
| `adTtl` | `Duration` | `Duration(minutes: 50)` | Age after which a loaded ad that was never shown is replaced |
| `timeouts` | `AdTimeoutConfig` | `AdTimeoutConfig.standard` | Adaptive network timeout profile |
| `testDeviceIds` | `List<String>?` | `null` | AdMob test device hashed identifiers |
| `analytics` | `AdAnalyticsTracker?` | `null` | Impression-level revenue and funnel tracker |
| `diagnostics` | `AdDiagnosticsTracker?` | `null` | Internal network latency and timeout diagnostics |
| `logLevel` | `AdLogLevel?` | `null` | Verbose in debug builds; silent in release builds |

## Network Timeout Profiles

`AdTimeoutConfig` provides adaptive download windows separating fullscreen, inline, and splash formats:

| Profile | Fullscreen (Wi-Fi / Cellular) | Splash (Wi-Fi / Cellular) | Inline (Wi-Fi / Cellular) | Best Use Case |
| :--- | :--- | :--- | :--- | :--- |
| `standard` | 30s / 50s | 25s / 45s | 20s / 35s | Default for global mobile networks |
| `emergingMarkets` | 45s / 75s | 35s / 65s | 30s / 50s | Regions with 2G/3G or high latency (Ethiopia, Pakistan) |
| `relaxed` | 35s / 60s | 30s / 50s | 25s / 40s | Apps with large media assets |
| `aggressive` | 15s / 25s | 15s / 25s | 10s / 15s | Low-latency Tier-1 environments |

## Status and Privacy Methods

| Method / Getter | Return Type | Purpose |
| :--- | :--- | :--- |
| `initializationState` | `AdInitializationState` | Current stage: `uninitialized`, `gatheringConsent`, `initializingSdk`, `ready`, `consentDenied`, `failed`, or `disposed` |
| `initializationStateListenable` | `ValueListenable<AdInitializationState>` | Observable stage for reactive status interfaces |
| `isReady(placement)` | `bool` | Reports whether a fresh ad is cached and ready now |
| `isLoading(placement)` | `bool` | Reports whether in-flight loading or retry work exists |
| `getState(placement)` | `AdPlacementState` | Returns buffer state: `unloaded`, `loading`, `ready`, or `error` |
| `watchState(placement)` | `Stream<AdPlacementState>` | Stream of placement state changes |
| `isShowingAd` | `bool` | Reports whether a fullscreen ad holds presentation ownership |
| `isUserPremium` | `bool` | Returns current result of configured `isPremium` callback |
| `canRequestAds` | `bool` | Snapshot of consent and SDK readiness |
| `waitUntilCanRequestAds()` | `Future<bool>` | Awaits eligibility resolution |
| `isPrivacyOptionsRequired()` | `Future<bool>` | Checks if Google UMP requires a settings entry point |
| `showPrivacyOptionsForm()` | `Future<bool>` | Opens the UMP consent form for user updates |
| `openAdInspector([onComplete])` | `void` | Opens Google Ad Inspector for on-device testing |

## Telemetry Contracts

### `AdAnalyticsTracker`

Implement `AdAnalyticsTracker` to capture revenue and lifecycle events:

- `onAdRequested(placement)`: Emitted once when a logical load cycle begins.
- `onAdLoaded(placement, loadTime)`: Emitted once when an ad becomes ready in memory. `loadTime` runs from the request to ready and includes queue wait; diagnostics report network time alone.
- `onAdFailedToLoad(placement, error, errorCode)`: Emitted once upon terminal load failure.
- `onAdDisplayed(placement)`: Emitted when an ad renders on screen.
- `onAdDismissed(placement)`: Emitted when an ad is closed.
- `onAdClicked(placement)`: Emitted when a user taps the ad.
- `onPaidEvent(placement, revenue)`: Emitted with precision and revenue value (`value`, `currencyCode`, `micros`).

### `AdDiagnosticsTracker`

Implement `AdDiagnosticsTracker` to monitor network health:

- `onDiagnosticReport(report)`: Receives diagnostic reports containing attempt number, elapsed time, error codes, and network type.
- Event types: `requested`, `loaded`, `failedToLoad`, `timeout`, `retryScheduled`, `circuitBroken`, `staleEvicted`, and `blackHoleSuspected`.

## Test Ad Identifiers

Use official AdMob test identifiers during development:

| Ad Format | Android Test Unit ID | iOS Test Unit ID |
| :--- | :--- | :--- |
| **Banner** | `AdMobTestIds.bannerAndroid` | `AdMobTestIds.bannerIos` |
| **Native** | `AdMobTestIds.nativeAndroid` | `AdMobTestIds.nativeIos` |
| **Interstitial** | `AdMobTestIds.interstitialAndroid` | `AdMobTestIds.interstitialIos` |
| **Rewarded** | `AdMobTestIds.rewardedAndroid` | `AdMobTestIds.rewardedIos` |
| **Rewarded Interstitial** | `AdMobTestIds.rewardedInterstitialAndroid` | `AdMobTestIds.rewardedInterstitialIos` |
| **App Open** | `AdMobTestIds.appOpenAndroid` | `AdMobTestIds.appOpenIos` |

`AdMobTestIds` also exports sample application IDs:
- `AdMobTestIds.androidAppId`
- `AdMobTestIds.iosAppId`
- `AdMobTestIds.nativeVideoAndroid`
- `AdMobTestIds.nativeVideoIos`
