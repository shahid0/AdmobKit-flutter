# Changelog

## 0.1.2

- Fixed: a fullscreen native ad in a `PageView` kept the presentation lock after its page was swiped away, so every later `show` was skipped. Fullscreen natives now own the screen only while more than half of them is on screen, and regain it with the same ad when swiped back.

## 0.1.1

- Documentation: the pub.dev page now includes the full usage guide, and every guide link works on pub.dev.

## 0.1.0

The first release since 0.0.2. Upgrading? Follow [Migrating from 0.0.2](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/migration.md). The reasoning behind each behavior is in [Design decisions](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/design-decisions.md).

### Highlights

- 19 built-in native templates with live styling (`NativeAdStyle`, `AdmobKit.setNativeStyle`), measured heights, and fullscreen pages.
- Banner sizing: anchored adaptive (default), inline adaptive, fixed sizes, and collapsible banners. Fixed banners preload.
- `AdmobKit.waitForAll` prepares a funnel step, such as all onboarding ads while the splash screen is up.
- `waitFor` is deterministic: it settles when the ad is ready or cannot come, and returns `false` at once while offline. `timeout` is an optional time budget.
- Ad widgets in tabs, pages, and lists need no setup: each ad goes to one visible widget and stays with it.
- A "Loading ad" shimmer placeholder for reserved banner space and native ads.
- Full guides: recipes, best practices, design decisions, API reference, migration, and an AI agent skill.

### Breaking changes

- Import `package:admob_kit_flutter/admob_kit_flutter.dart`; `flutter_ads.dart` is removed.
- Removed `AdmobKit.preload`, `leaseInlineAd`, `pool`, `logger`, and the testing hooks.
- Native ads use built-in templates: removed `NativePlacement.big/medium/small`, `factoryId`, `AdNativeView.templated`, and `AdNativeView`'s `template`, `width`, and `height`.
- `AdBannerView` sizing moves to `BannerPlacement.sizing`; the default banner is anchored adaptive.
- `registerPlacements` before `initialize()` throws `StateError`.
- `AdPriority.immediate` now outranks `splash`.
- Longer default request timeouts (`AdTimeoutConfig.standard`).
- `AdLogger`, `AdNetworkInfo`, and some `AdMobTestIds` app IDs are no longer exported.

### Added

- `initializationState`, `initializationStateListenable`, `waitUntilCanRequestAds`, and `isPrivacyOptionsRequired`.
- Timeout profiles `emergingMarkets`, `relaxed`, and `aggressive`.
- `DebugGeography` export for consent testing.

### Changed

- The ad the user is waiting for loads first; `waitFor` and visible widgets jump the queue.
- Adaptive banners size to the rendered creative and keep the current banner during rotation.
- Only ads that were never shown expire.
- One-time ads whose screen the user already left are no longer loaded later.
- `AdPaywallGuard` exits once, ignoring repeated taps.

### Fixed

- A fullscreen placement with capacity 2 or more buffers distinct ads.
- A fullscreen ad Android refuses to show no longer blocks later ads.
- `waitFor` recovers after a placement's retries run out.
- Empty banner and native slots try again when the app returns to the foreground.

### Known limits

- Native templates can truncate copy at narrow widths or large text scales. Test before release; see [Native ads](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/native-ads.md#policy-and-production-limits).

## 0.0.2

### Fixed

- Two widgets sharing a placement each get their own ad, ending "This AdWidget is already in the Widget tree" crashes.
- Splash presentation no longer races with other fullscreen ads.
- Rapid calls and tab switches no longer start duplicate downloads.
- Terminal load failures settle waiting widgets at once instead of after a timeout.
- The buffer refills after an ad is delivered straight to a waiting widget.
- Tabs that failed offline retry when shown again.
- Leasing or preloading after `dispose()` is a safe no-op.

### Changed

- `waitFor` and empty-buffer widget leases jump to the front of the queue.
- Hidden `IndexedStack` tabs wait until selected before requesting.
- Removed the `FlutterAds` and `FlutterAdsConfig` aliases; use `AdmobKit` and `AdmobKitConfig`.

### Added

- `placementCapacities` for several visible widgets sharing a placement.
- `AdmobKit.dispose()`.
- README API reference and an agent skill.

## 0.0.1

Initial release.

- Preloading queue with `waitFor` and `show` for interstitial, rewarded, rewarded interstitial, and app-open ads.
- Google UMP consent with debug geography.
- One fullscreen ad at a time.
- `AdBannerView`, `AdNativeView`, and `AdPaywallGuard` widgets.
- Analytics and diagnostics tracker contracts.
