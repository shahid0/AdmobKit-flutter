# Public API

Use this import for app integration:

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

The package controls ad loading and lifetime. The app controls navigation, rewards,
placement reachability, purchase state, and display frequency.
For working sequences, read [Use cases](recipes.md).

## Start and register

`AdmobKit.initialize({AdmobKitConfig config = const AdmobKitConfig()})` returns `Future<void>`.
It starts consent collection, ATT on iOS, SDK initialization, and native factory registration.
Start it once before registration or mounting ad widgets. The app can render while this future is pending.
Catch initialization errors. A denied consent decision completes initialization without an exception;
it does not permit ads. Initialization completion does not mean an ad is loaded.

Repeated calls share the active initialization and its first configuration.
To replace configuration, call `dispose`, then initialize again.
After a failed initialization, call initialize again and register the required placements again.

`registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? placementCapacities})` returns `void`.
It records placements and starts eligible background loading. It accepts calls during initialization.
Call it again when more screens become reachable. It throws `StateError` before initialization or after disposal.
Banner registration does not load a banner: the widget must supply width and orientation.

Use unique placement IDs. An ID has one configuration during the session.
Changing its unit IDs, format, template, sizing, style, or loading flags throws `ArgumentError`.
Use `setNativeStyle` for a live style change instead of replacing the placement.
Capacities must be positive integers. A capacity is the target number of buffered ads, not an impression limit.

Registration controls background loading, not permission to access a placement.
`waitFor` and an active inline widget can request an unregistered placement.
Do not mount an unreachable screen merely because its placement was not registered.

## Wait for an ad decision

`waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout})` returns `Future<bool>`.

It waits for current consent, ATT, SDK, and privacy resolution. Then it checks or requests the ad.
It promotes pending work for that placement. No extra consent or readiness check is needed.

- `true`: A fresh buffered ad is available at that time.
- `false`: No initialization, consent denial, initialization failure, premium access, disposal,
  ad failure, timeout, or an exhausted `loadOnce` buffer.

This result does not reserve an ad or the display lock. Another widget or request can consume the ad later.
`show` still checks availability and ownership. Always handle the app action through its callbacks.
A false result does not cancel all background retries.

`timeout` limits the ad wait after eligibility resolution. It does not limit the consent form or SDK initialization.
An omitted timeout uses the configured network policy. If the app has a total startup deadline,
the app owns that deadline and must avoid later duplicate navigation or presentation.

For explicit banner waits, supply the future host's actual `BannerLayout`.
Its `width` is a positive integer in logical pixels. Its `orientation` is
`BannerOrientation.portrait` or `.landscape`. Different layouts do not share a ready result.
Normal banner integration needs only `AdBannerView`; do not estimate the banner height.

## Show an SDK fullscreen ad

`show(FullscreenPlacement placement, {VoidCallback? onDismissed, VoidCallback? onDisplayed,
void Function(num amount, String type)? onRewardGranted})` returns `void`.

It presents a fresh cached interstitial, rewarded, rewarded-interstitial, or app-open ad.
It skips presentation if ads are blocked, the cache is unavailable, or another ad owns presentation.
Before initialization, it skips the ad and calls `onDismissed`.

Normal placements do not wait for a download. A splash placement with an existing load can wait for that load.
This is not a promise of zero SDK presentation latency. Use `waitFor` explicitly for a startup waiting sequence.

- `onDisplayed`: The SDK reports that the ad was displayed. A skipped ad does not call it.
- `onDismissed`: The ad closes, cannot be shown, or is skipped. Complete navigation or the normal action here.
- `onRewardGranted`: The SDK reports an earned reward. Grant rewards here, not in `onDismissed`.

Each call represents a separate app action. Disable or otherwise guard repeated app actions when needed.
Keep callbacks short and do not throw from them. The library handles ad ownership; it does not deduplicate navigation.
Do not call `show` for native placements, including fullscreen native templates. They use `AdNativeView`.

## Place ads in a layout

`AdBannerView({required BannerPlacement placement, double? width, Widget? placeholder, bool active = true})`
uses available logical width and device orientation to request an adaptive banner.
Supply `width` only when the parent width is unbounded. Invalid width throws `FlutterError`.
Anchored banners use SDK-selected height. Inline banners reserve `sizing.maxHeight` and center the actual creative.
The optional placeholder appears during a pending request. Do not add a guessed fixed height.

`AdNativeView({required NativePlacement placement, bool active = true, Widget? placeholder,
bool showPlaceholder = true})` owns its ad instance and its disposal.
It needs bounded width of at least 320 logical pixels. Inline height follows measured content.
Fullscreen templates also need bounded height of at least 320 and sufficient room for their assets.
Invalid host bounds throw `FlutterError`; a failed native measurement does not display the ad.
Read [Native ads](native-ads.md) for the catalog and known production limit.

Both widgets respect `Visibility`, `TickerMode`, and `active`.
Native hosts also react to app lifecycle changes. Mounting is not a viewport visibility detector.
For retained or lazy pages, pass `active` from the selected page or tab.
Different hosts receive distinct ad instances, even when they share a placement.

`AdPaywallGuard({required FullscreenPlacement placement, required VoidCallback onDismiss,
Widget? child, Widget Function(BuildContext, VoidCallback)? builder, bool isPurchased = false})`
routes its close trigger and intercepted system back action through `show`.
Provide `child` or `builder`. If both are provided, `builder` takes precedence.
Pass the builder's trigger to the close button. `isPurchased` or premium access bypasses the ad.
The app owns the final dismiss action and its navigation policy.

## Placements

All placements require `androidId` and `iosId`. Give each logical location an explicit `id`.
Without one, the Android unit ID becomes the ID. Shared unit IDs do not imply shared placement configuration.
All constructors accept `priority` and `loadOnce`.

| Type | Extra options | Default priority |
| --- | --- | --- |
| `InterstitialPlacement` | `isSplash` | `high`, or `splash` |
| `AppOpenPlacement` | `isSplash` | `high`, or `splash` |
| `RewardedPlacement` | None | `medium` |
| `RewardedInterstitialPlacement` | None | `medium` |
| `BannerPlacement` | `isSplash`, `sizing` | `medium`, or `splash` |
| `NativePlacement` | `isSplash`, `template`, `style` | `medium`, or `splash` |

`loadOnce` defaults to false. When true, consumption stops background replenishment.
Remaining buffered ads can still be used. A new inline host can request another ad after consumption.
It is not an install-level display limit. The app controls first-run screen access.
Consumption is retained through privacy updates in the same session. A new initialization after disposal resets it.

`BannerSizing.anchoredAdaptive()` is the default.
`BannerSizing.inlineAdaptive({required int maxHeight})` selects inline sizing; use at least 32 logical pixels.
`NativePlacement` defaults to `NativeAdTemplate.cardContentTop` and an inherited `NativeAdStyle`.

`AdPriority` values are `splash`, `immediate`, `high`, `medium`, and `low`.
Choose initial priority for reachable placements. Visible demand and `waitFor` are promoted by the library.
You do not need to manage a queue or implement priority changes in the app.

## Appearance

`setNativeStyle(NativeAdStyle style, {NativePlacement? placement})` returns `Future<void>`.
Omit `placement` to replace global style. Supply it to replace that placement's live override.
It updates existing and future native renders without requesting replacement ads.
Await it and handle platform errors. It throws `StateError` without an active appearance session.

`NativeAdStyle` has nullable unsigned ARGB integers: `background`, `headline`, `body`,
`callToActionBackground`, and `callToActionText`.
`callToActionCornerRadius` is a nullable, finite, non-negative number of logical pixels.
Zero makes square corners. Larger values clamp to half the button height. Null inherits the next scope.
Invalid values throw `ArgumentError` when validated. The native default CTA radius is 8.

The effective placement style is its live override, if present, or its constructor style otherwise.
That effective style inherits global style, then native defaults.
Each update replaces its entire scope. `const NativeAdStyle()` resets that scope to inheritance.
The `body` color also styles advertiser, price, rating, and separator text.
Choose legible colors and contrast. Styling cannot replace the SDK assets or their click handling.

## Privacy and eligibility

`canRequestAds` is a synchronous snapshot. False can mean that initialization or privacy resolution is still pending.
Do not use it to skip a first `waitFor` call or widget load.

`waitUntilCanRequestAds()` returns `Future<bool>` after current eligibility resolution.
It does not request an ad or start initialization. Use it only when the app needs an eligibility decision.
`waitFor` already includes this step. Denial, failure, premium access, disposal, or no initialization returns false.

`isPrivacyOptionsRequired()` returns `Future<bool>` after initialization or a current privacy update.
It checks the UMP requirement even when ads are denied. SDK query errors propagate; an error is not a false decision.
An unknown SDK requirement throws `StateError` instead of reporting not required.
Before initialization or after disposal, it returns false.

`showPrivacyOptionsForm()` returns `Future<bool>`. It waits for initialization and does not cover an active fullscreen ad.
It resolves the new consent decision and refreshes eligible loading afterward.
True means the form completed without a reported error, not that ads are allowed.
False means unavailable, blocked presentation, form failure, disposal, or no session.
Concurrent calls share the current form operation. See [Privacy settings](recipes.md#privacy-settings).

## Status and diagnosis

These methods are not required for normal ad loading:

| Member | Result |
| --- | --- |
| `initializationState` | Current `AdInitializationState` |
| `initializationStateListenable` | `ValueListenable<AdInitializationState>` for a status UI |
| `isReady(placement, {bannerLayout})` | A fresh buffered ad is available now |
| `isLoading(placement, {bannerLayout})` | Queued, running, or retry work exists |
| `getState(placement, {bannerLayout})` | Current `AdPlacementState` |
| `watchState(placement, {bannerLayout})` | Stream of placement states |
| `isShowingAd` | SDK fullscreen or loaded active fullscreen-native ownership |
| `isUserPremium` | Current result of the configured premium callback |
| `openAdInspector([void Function(String? error)? onComplete])` | Opens SDK inspection; null error indicates no reported error |
| `dispose()` | Ends the session and releases package-owned resources |

Initialization states are `uninitialized`, `gatheringConsent`, `initializingSdk`, `ready`,
`consentDenied`, `failed`, `updatingConsent`, and `disposed`.
Placement states are `unloaded`, `loading`, `ready`, and `error`.
They describe the loading buffer, not whether a widget currently displays an owned ad.
Before initialization, placement snapshots are unavailable and `watchState` is an empty stream.
Explicit banner state queries need `bannerLayout`.
Freshness checks can evict stale cache entries and start normal replacement work.
State streams belong to the current loading lifetime. A privacy update or disposal can close them;
create a new subscription after the initialization state changes.

`isShowingAd` does not track app dialogs, paywalls, or permission prompts.
`dispose` is for the app/session owner, not for every screen exit. Widgets dispose their own ads.

## Configuration

Keep defaults unless the app has a specific need.
Concurrency, TTL, and configured request timeouts must be positive.
Invalid loading configuration throws `ArgumentError` before initialization starts.

| `AdmobKitConfig` field | Default | Use |
| --- | --- | --- |
| `placements` | null | Known initial placements; later registration is also supported |
| `requestConsent` | true | Run package UMP and ATT collection; false skips that collection |
| `consentTestConfig` | null | `ConsentTestConfig(debugGeography:, testIdentifiers:)` on test devices only |
| `isPremium` | null | `bool Function()` returning current ad-free entitlement |
| `nativeStyle` | `const NativeAdStyle()` | Initial global native style |
| `initialConcurrency` | 1 | Maximum initial concurrent requests |
| `subsequentConcurrency` | 1 | Maximum later concurrent requests |
| `placementCapacities` | null | Map from placement IDs to positive buffer capacities; default capacity is 1 |
| `adTtl` | 50 minutes | Freshness limit for cached and reactivated inline ads |
| `timeouts` | `AdTimeoutConfig.standard` | Network timeout profile |
| `testDeviceIds` | null | AdMob test-device identifiers |
| `analytics` | null | `AdAnalyticsTracker` implementation |
| `diagnostics` | null | `AdDiagnosticsTracker` implementation |
| `logLevel` | verbose in debug; none in release | `AdLogLevel` verbosity |

`requestConsent: false` is not proof of consent. Use it only when the app deliberately owns collection outside this package.
Read [Platform setup](setup.md) before changing privacy behavior.

The premium callback is queried, not subscribed to. Rebuild ad hosts when entitlement changes.
A stale retained inline ad is checked on reactivation, not replaced while a user is viewing it.

`AdTimeoutConfig` contains `fullscreen`, `inline`, and `splash` policies.
Each `AdTimeoutPolicy` has `wifiTimeout`, `cellularTimeout`, `ethernetTimeout`, and `otherTimeout`.
The standard profiles, in that order, are 15/25/12/20 seconds for fullscreen and splash,
and 10/15/8/12 seconds for inline. `aggressive` and `relaxed` are optional profiles.
`AdNetworkType` has `wifi`, `cellular`, `ethernet`, `none`, and `unknown`.
`none` and `unknown` use the other timeout. No timeout guarantees an ad will be available.

## Events and test IDs

Implement all methods of `AdAnalyticsTracker`: `onAdRequested`, `onAdLoaded`, `onAdFailedToLoad`,
`onAdDisplayed`, `onAdDismissed`, `onAdClicked`, and `onPaidEvent`.
`onAdLoaded` includes elapsed load time. Load failure includes an error string and optional SDK code.
`onPaidEvent` includes `AdRevenueValue`: `micros`, `currencyCode`, `precision`, and the converted `value`.
Precision is `unknown`, `estimated`, `publisherProvided`, or `precise`.
Do not grant rewards from analytics events.
Currently, `onAdDisplayed` and `onAdDismissed` report SDK fullscreen events only.
Inline impressions are not connected to those analytics callbacks. Inline load, click, and paid callbacks remain available.

`AdDiagnosticsTracker.onDiagnosticReport` receives an `AdDiagnosticReport` with placement ID, format,
event type, attempt number, elapsed time, SDK error information, network type, timestamp, and metadata.
`AdDiagnosticEventType` values are `requested`, `loaded`, `failedToLoad`, `timeout`, `retryScheduled`,
`circuitBroken`, `staleEvicted`, `blackHoleSuspected`, `displayed`, and `dismissed`.
Availability of an event depends on the actual path taken.
The `displayed` and `dismissed` diagnostic enum values are not currently emitted by package paths.

| `AdFormat` | Android test unit | iOS test unit |
| --- | --- | --- |
| `banner` | `AdMobTestIds.bannerAndroid` | `AdMobTestIds.bannerIos` |
| `native` | `AdMobTestIds.nativeAndroid` | `AdMobTestIds.nativeIos` |
| `interstitial` | `AdMobTestIds.interstitialAndroid` | `AdMobTestIds.interstitialIos` |
| `rewarded` | `AdMobTestIds.rewardedAndroid` | `AdMobTestIds.rewardedIos` |
| `rewardedInterstitial` | `AdMobTestIds.rewardedInterstitialAndroid` | `AdMobTestIds.rewardedInterstitialIos` |
| `appOpen` | `AdMobTestIds.appOpenAndroid` | `AdMobTestIds.appOpenIos` |

`AdMobTestIds` also provides `androidAppId`, `iosAppId`, `nativeVideoAndroid`, and `nativeVideoIos` for test integrations.
`AdLogLevel` is `verbose`, `info`, `warning`, `error`, or `none`.
Application callbacks must handle their own service errors. Do not let tracking failures interrupt an ad action.
