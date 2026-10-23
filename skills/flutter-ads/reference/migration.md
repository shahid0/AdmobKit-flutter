# Migrating from 0.0.2 to 0.1.0

0.1.0 is the first release after 0.0.2. It replaces native factories with built-in templates, adds banner sizing, reworks loading behavior, and removes internal APIs from the public surface.
Work through the sections that apply to your app, then read [Best practices](best-practices.md) for the recommended way to use each API.

## Imports

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `package:admob_kit_flutter/flutter_ads.dart` | `package:admob_kit_flutter/admob_kit_flutter.dart` |
| `import 'package:google_mobile_ads/...'` for `DebugGeography` | `DebugGeography` is exported by AdmobKit |

## Facade

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `AdmobKit.preload(placement)` | `AdmobKit.registerPlacements([...])` to preload, or `AdmobKit.waitFor(placement)` when a flow needs the ad |
| `AdmobKit.leaseInlineAd`, `AdmobKit.pool`, `AdmobKit.logger` | Removed. Mount `AdBannerView` or `AdNativeView`; use `logLevel`, `analytics`, and `diagnostics` in `AdmobKitConfig` |
| `AdmobKit.driverForTesting`, `networkInfoForTesting`, `setPoolForTesting` | Removed from the public API |
| `isReady`, `isLoading`, `getState`, `watchState`, `waitFor` | Unchanged for most placements; adaptive banners take an optional `bannerLayout` |

New: `initializationState`, `initializationStateListenable`, `waitForAll`, `waitUntilCanRequestAds`, `isPrivacyOptionsRequired`, and `setNativeStyle`.

Behavior changes:
- `registerPlacements` before `initialize()` now throws `StateError` instead of logging a warning.
- Repeated `initialize()` calls share the first session until `dispose()`. Call `dispose()` before initializing with a new configuration.
- `initialize()` throws `ArgumentError` for a concurrency below 1, or a TTL or timeout of zero or less.
- `canRequestAds` is `false` while initialization runs and for premium users.

## Native ads

Native ads now render through 19 built-in templates. Delete the Android XML layouts and iOS XIB factories your app registered for 0.0.2.

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `NativePlacement.big(...)` / `.medium(...)` / `.small(...)` | `NativePlacement(template: NativeAdTemplate.feedMediaFirst / .cardContentTop / .rowWithLeadingIcon)` |
| `NativePlacement(factoryId: ...)` | `NativePlacement(template: ...)` |
| `NativeAdTemplate.big` / `.medium` / `.small` | One of the 19 templates; see [Native ads](native-ads.md) |
| `AdNativeView.templated(...)`, `AdNativeView(template:, height:, width:)` | `AdNativeView(placement: ...)`; the template comes from the placement and the height from measured content |
| Colors in your native factory | `NativeAdStyle` on the placement or `AdmobKitConfig.nativeStyle`, updated live with `AdmobKit.setNativeStyle` |

```dart
const feedNative = NativePlacement(
  id: 'feed_native',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.feedMediaFirst,
);
```

`AdNativeView` now needs a bounded width of at least 320 logical pixels and sizes itself to its content. Do not wrap inline native ads in fixed-height boxes.

## Banners

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `AdBannerView(height: 50, width: 320)` | `BannerPlacement(sizing: ...)` and `AdBannerView(placement: ...)` |
| Fixed 320×50 box by default | Anchored adaptive banner at the parent's width by default |

```dart
const footerBanner = BannerPlacement(
  id: 'footer',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
);

const standardBanner = BannerPlacement(
  id: 'standard',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.standard(),
);
```

- Adaptive banners load when their widget lays out; fixed banners (`standard`, `mrec`, `large`, `leaderboard`, `fixed`) preload at registration.
- `AdBannerView` throws `FlutterError` when its width is unbounded. Supply `width:` in unbounded parents.
- Collapsible banners: `BannerPlacement.collapsible(...)`.

## Visibility

0.0.2 deferred loading through `TickerMode` and `Visibility`, and asked apps to wrap `PageView` and `TabBarView` pages themselves. In 0.1.0 none of this needs app code: lazy pages build only when visible, a returning ad goes to a visible widget, and a delivered ad stays with its widget. Remove any wrappers you added for ad loading.

## Configuration

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `AdmobKitConfig(retryScheduler: ...)`, `AdmobKitConfig(initializeNativeGma: ...)` | Removed |
| Default timeouts 15–25 s (fullscreen) | `AdTimeoutConfig.standard`: 30 s Wi-Fi / 50 s cellular for fullscreen. Profiles: `standard`, `emergingMarkets`, `relaxed`, `aggressive` |
| — | `AdmobKitConfig(nativeStyle: ...)` |

## Types

| 0.0.2 | 0.1.0 |
| :--- | :--- |
| `AdLogger`, `AdNetworkInfo` exported | No longer exported. `AdNetworkType` remains |
| `AdPriority` operators `<`, `>`, `>=` | Only `<=` remains; `immediate` now outranks `splash` |
| `AdFormat` order | Changed; do not rely on `.index` or `values` order |
| `AdMobTestIds.androidAppId`, `iosAppId`, `nativeVideoAndroid`, `nativeVideoIos` | Removed. Use the app IDs from [Platform setup](setup.md) |
| `AdRevenueValue` value equality | Identity equality |

## After migrating

1. Run `flutter analyze` and fix the remaining compile errors using the tables above.
2. Rebuild the app (`flutter clean`, then `flutter run`) so native template factories register.
3. Check each ad screen on a device with test ad unit IDs.
