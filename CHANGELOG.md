# Changelog

All notable changes to the `admob_kit_flutter` package will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

Major feature milestone: replaces legacy XML/XIB layout bindings with nine built-in native ad templates, introduces the `NativeAdStyle` engine with live theming and CTA corner radius via Pigeon, adds adaptive banner sizing, and stabilizes presentation lifecycle locks with `AdSession`.

### Breaking Changes

- **Removed XML/XIB native factories**: Removed Android XML (`big_native_ad.xml`, etc.) and iOS XIB layout bindings. All native ads now render through nine built-in, platform-native templates.
- **Replaced `NativeAdColors` with `NativeAdStyle`**: Replaced colors-only styling with `NativeAdStyle` (adds `callToActionCornerRadius` alongside `background`, `headline`, `body`, `callToActionBackground`, `callToActionText`).
- **Updated `NativePlacement` signature**: Replaced `colors:` with `style:`. Layout template is now configured via `template:` (`NativeAdTemplate.cardContentTop` by default).
- **Distinct Native Compositions**: Nine named layouts: three cards, three feed layouts, and three fullscreen layouts. Removed misleading text-only, responsive side-action, split, and duplicate variants rather than preserving aliases. The default is `cardContentTop`.
- **Content-sized Inline Natives**: `template.height` is now a loading estimate. Inline hosts measure real SDK assets at their available width and Flutter text scale; do not constrain them to the estimate. Fullscreen hosts remain bounded.
- **Adaptive Banner Sizing**: `BannerPlacement` now uses `BannerSizing` (`BannerSizing.anchoredAdaptive()` default or `BannerSizing.inlineAdaptive(maxHeight:)`). Removed fixed height property.

### Added

- **Nine Built-in Native Templates**: Card, Feed Card, and Fullscreen compositions with native-measured sizing via Pigeon.
- **3 Canonical Template Presets**: `NativeAdTemplate.stackedCard`, `feedCard`, `fullscreen`.
- **Live Dynamic Native Styling**: `AdmobKit.setNativeStyle(style, placement:)` instantly updates cached, pending, and rendered native ads without triggering reloads.
- **Configurable CTA Corner Radius**: `callToActionCornerRadius` supports square (0), rounded (6/8), or pill buttons via native canvas clipping.
- **Fullscreen Native Placement**: Added full-screen native host support (`fullscreenMediaFirst`–`fullscreenActionMiddle`) with exclusive presentation mutex integration.
- **Adaptive Banner Support**: Width and orientation-aware anchored and inline adaptive banners via `BannerLayout` and SDK native sizing.
- **Initialization State Machine**: Added `AdInitializationState` and `AdmobKit.initializationStateListenable` for reactive UI monitoring without polling.
- **Explicit Viewport Gating**: Added `active:` flag on `AdNativeView` and `AdBannerView` for manual activation control in retained `PageView` or tab containers.
- **Interactive Showcase Gallery**: Full gallery screen in example app demonstrating all nine native templates, adaptive banners, live palette switcher, and diagnostics console.

### Changed

- **Compact Native Identity**: Shared 64-pixel icons, naturally wrapping headline/CTA copy, single-line optional body copy, inline "Ad · rating ★ · price" metadata, and rounded CTA defaults on Android/iOS. Body copy is omitted if its complete text cannot fit one line. Missing optional assets collapse; provided icons and video remain visible. Asset order stays consistent across supported widths; every CTA occupies its own full-width row.
- **Fullscreen Navigation**: No built-in top close button. Example screens use bottom Continue navigation outside SDK ad assets.
- **Platform Alignment**: Aligned with Google Mobile Ads 25.4.0 (Android) and 13.7.0 (iOS). Example app targets iOS 15.0+; core plugin continues to support iOS 13.0+.

### Fixed

- **Catalog Accuracy**: Gallery labels and previews now match native asset order on both platforms. Geometry tests catch duplicate compositions and preserve card ordering when video is supplied.

- **Native Layout Races**: Stale resize measurements cannot mount an ad or acquire fullscreen ownership after unmounting, disposal, or a newer layout request. Fullscreen ownership begins only after layout is measured successfully.
- **Native Asset Clipping**: Long copy and scaled text grow naturally; insufficient fullscreen media space is rejected instead of clipping required assets. SDK AdChoices retains its own corner.
- **Android High-Density Corner Scaling**: Fixed bug where card corners were density-scaled twice on high-DPI Android devices.
- **Deterministic Splash Settlement**: Prevented presentation mutex race condition when awaiting splash ads during cold-start.
- **Multi-Widget Memory Isolation**: Guaranteed distinct native ad instances when multiple widgets share a placement, eliminating `This AdWidget is already in the Widget tree` crashes.
- **Stale Session Cleanup**: Auto-evicted expired cached ads on route deactivation.

## 0.0.2

Hardening release: eliminates three classes of silent production failures (multi-widget ad collisions, splash presentation races, and AdMob request storms), removes the legacy `FlutterAds` facade alias, and overhauls the README and AI-agent skill with a complete API reference, behavioral guarantees, and a table of contents.

### Fixed

- **Multi-widget ad collisions (critical)**: Leasing an inline ad (`AdBannerView`, `AdNativeView`) is now demand-based and async. Two widgets requesting the same placement each receive their own exclusively-owned ad instance — the fatal `This AdWidget is already in the Widget tree` crash is structurally impossible. Previously the losing widget rendered a permanent blank placeholder.
- **Splash presentation race (critical)**: During splash settlement, the presentation mutex is now held for the entire window. Concurrent fullscreen triggers are deterministically rejected instead of colliding mid-settlement, and the settled splash presents directly without a re-entrant lock acquisition that could silently drop it.
- **AdMob request storms**: `preload()` now counts queued, in-flight, and retry-timer tasks against capacity. Rapid calls, tab switches, and concurrent leases no longer spawn duplicate parallel downloads for the same demand.
- **15-second placeholder hangs on load failure**: Terminal load failures (e.g. fatal AdMob error codes, circuit breaker) now settle waiting inline leases immediately instead of letting them hang until timeout. Retryable failures still retry per the backoff policy.
- **Buffer starvation after demand delivery**: After an ad is delivered directly to a waiting widget, the warm buffer is re-armed automatically so the next viewer still gets a 0ms lease.
- **Blank tabs after offline reactivation**: An ad widget whose load failed offline resets its attempt flag when deactivated, so returning to the tab after reconnection retries the lease instead of staying blank forever.
- **Disposed-pool safety**: `leaseInlineAd` and `preload` after `dispose()` are now safe no-ops instead of registering waiters into a dead queue.

### Changed

- **Priority promotion on visible demand**: `waitFor()` and empty-buffer widget leases now promote their placement to the `immediate` tier, so the on-screen ad preempts background preloads instead of queueing behind them.
- **Deferred loading for tab structures**: Ad loads now gate on both `TickerMode` (route coverage) and `Visibility` — hidden `IndexedStack` tabs defer their ad requests until selected. (`TabBarView`/`PageView` pages still need an explicit `TickerMode`/`Visibility` wrap; documented.)
- **Inline dedup performance**: Deduplication scans are skipped for slot-keyed inline tasks, keeping the common preload path O(1).
- **Removed legacy `FlutterAds` / `FlutterAdsConfig` aliases**: Use `AdmobKit` and `AdmobKitConfig` (same members, one-line find/replace). Import path is `package:admob_kit_flutter/admob_kit_flutter.dart`.

### Added

- **Per-placement buffer capacity**: `AdmobKitConfig.placementCapacities` and `registerPlacements(placementCapacities:)` for the rare case of multiple simultaneously-visible widgets sharing one placement. Default depth 1 is recommended otherwise.
- **`AdmobKit.dispose()`** for full pool/queue/mutex teardown in test harnesses and hot-restart flows.
- **`AdNetworkInfo` testing seam** (`networkInfoForTesting`) so widget tests can simulate network conditions.
- **Complete API surface documentation**: README now includes a table of contents, facade/config/placement reference tables, the priority & capacity scheduling model, ten concrete use cases (multi-widget screens, `IndexedStack` deferral, offline cold start, VIP suppression, EEA consent simulation, and more), an analytics-vs-diagnostics decision guide, and failure-behavior contracts.
- **Agent-first skill rewrite** (`skills/flutter-ads/SKILL.md`): API contracts, behavioral guarantee tables, negative constraints, the one-time-screen `loadOnce` registration rule, and an 11-point verification checklist tuned for AI coding agents.

## 0.0.1

Initial public release of **AdmobKit-flutter** (`admob_kit_flutter`) — a deterministic, production-grade Google AdMob framework for Flutter engineered to eradicate ad race conditions, presentation collisions, and layout shifts.

### Features

- **0ms Instant Presentation Contract**: Global eager preloading queue (`waitFor`, `show`) ensuring ads are in memory and displayed with zero perceptible delay.
- **Two-Stage Initialization**: Light config boot in `main()` with decoupled UMP consent gating and background warm-up.
- **Built-in Google UMP Consent Support**: Complete consent collection flow with GDPR, EEA, and customizable geographic debug simulation.
- **Strict Presentation Concurrency Leasing**: Eliminates simultaneous ad collision races and black-screen UI freezes.
- **Zero-CLS Layout-Stable Widgets**:
  - `AdBannerView`: Layout-stable adaptive banner widget with reservation containers that prevent Cumulative Layout Shift.
  - `AdNativeView` & `AdNativeView.templated`: Platform native ad widgets bound to pre-dimensioned templates (`NativeAdTemplate.small`, `medium`, `big`).
  - `AdPaywallGuard`: Hardware back-button interceptor and paywall close-button wrapper with deterministic frequency capping and cooldown guards.
- **Extensible Architecture**:
  - Built-in analytics tracking contracts (`AdAnalyticsTracker`).
  - Diagnostic monitoring and health telemetry (`AdDiagnosticsTracker`, `AdDiagnosticReport`).
  - Production logger contracts (`AdLogger`) with zero spam.
  - Full support for Banner, Interstitial, Rewarded, Rewarded Interstitial, Native, and App Open ad formats.
