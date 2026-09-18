# Changelog

All notable changes to the `admob_kit_flutter` package will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

