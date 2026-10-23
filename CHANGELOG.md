# Changelog

All notable changes to `admob_kit_flutter` are documented here.
This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

The first release since 0.0.2. Native ads move to 19 built-in templates with live styling, banners gain adaptive, fixed, and collapsible sizing, and loading is rebuilt around consent, priorities, deterministic waits, and one-visible-widget delivery. Internal APIs leave the public surface.
Upgrading from 0.0.2: read [Migrating from 0.0.2](doc/migration.md). The reasoning behind each behavior is in [Design decisions](doc/design-decisions.md).

### Breaking changes

- The only entry point is `package:admob_kit_flutter/admob_kit_flutter.dart`; `flutter_ads.dart` is removed.
- Removed `AdmobKit.preload`, `leaseInlineAd`, `pool`, `logger`, and the testing hooks `driverForTesting`, `networkInfoForTesting`, and `setPoolForTesting`. Registration preloads; `waitFor` prepares one placement.
- `AdLogger` and `AdNetworkInfo` are no longer exported.
- `AdmobKitConfig.retryScheduler` and `initializeNativeGma` are removed.
- Native ads render through built-in templates. Removed `NativePlacement.big()`, `.medium()`, `.small()`, `factoryId`, the `big`, `medium`, and `small` templates, `AdNativeView.templated`, and the `template`, `width`, and `height` parameters of `AdNativeView`. App-side XML and XIB native factories are no longer used.
- `AdBannerView` drops `width = 320` and `height = 50` defaults. Sizing comes from `BannerPlacement.sizing`, and the default banner is anchored adaptive at the parent's width.
- `registerPlacements` before `initialize()` throws `StateError`. `initialize()` throws `ArgumentError` for invalid concurrency, TTL, or timeouts, and repeated calls share the first session until `dispose()`.
- `AdPriority.immediate` now outranks `splash`, and only the `<=` operator remains. `AdFormat` order changed.
- Default request timeouts are longer: `AdTimeoutConfig.standard` allows 30 s on Wi-Fi and 50 s on cellular for fullscreen ads.
- Removed `AdMobTestIds.androidAppId`, `iosAppId`, `nativeVideoAndroid`, and `nativeVideoIos`.
- `AdRevenueValue` uses identity equality.

### Added

- 19 native templates in five families (compact rows, split media, cards, feeds, fullscreen), five aliases, and measured content heights.
- `NativeAdStyle` and `AdmobKit.setNativeStyle` for live colors and button radius, globally or per placement, without reloading ads.
- Fullscreen native templates that own the presentation lock while visible.
- `BannerSizing`: anchored adaptive, inline adaptive, fixed sizes (`standard`, `mrec`, `large`, `leaderboard`, `fixed`), and space reservation. `BannerPlacement.collapsible` for collapsible banners.
- Fixed banners preload at registration.
- `AdmobKit.waitForAll` prepares a funnel step by awaiting several placements in list order.
- `AdmobKit.initializationState`, `initializationStateListenable`, `waitUntilCanRequestAds`, and `isPrivacyOptionsRequired`.
- `AdTimeoutConfig.emergingMarkets`, `relaxed`, and `aggressive` profiles.
- `DebugGeography` is exported for consent testing.
- A shimmering "Loading ad" placeholder for reserved banner space and native ads, using the app's color scheme and respecting reduced motion.
- Best practices, design decisions, recipes, API reference, migration, and troubleshooting guides, plus an AI agent skill kept in sync with them.

### Changed

- `waitFor` is deterministic. It waits for consent and SDK setup, settles when the ad is ready or cannot come, and returns `false` at once while offline. `timeout` is an optional time budget.
- A failed splash wait ends the splash moment, so the following `show` does not wait again.
- The queue serves `immediate`, `splash`, `high`, `medium`, then `low`, first-in first-out within a tier; `waitFor` and mounted widgets move their request to the front.
- Visibility decides only when a widget requests and which visible widget receives a returning ad. Delivered ads stay with their widget across covered routes, tab switches, and scrolling, and lazy list or page items holding an ad stay alive.
- Adaptive banners load when their widget lays out, size to the rendered creative, and keep the current banner on screen while a new size loads after rotation.
- Only ads that were never shown are replaced after `adTtl`.
- Ads for `loadOnce` or splash widgets that left the screen before delivery are dropped instead of loading later.
- `AdPaywallGuard` starts its exit once, ignoring repeated taps and back presses.

### Fixed

- A fullscreen placement with capacity 2 or more buffers distinct ads instead of one ad several times.
- A fullscreen ad Android refuses to show releases the presentation lock and calls `onDismissed`.
- `waitFor` requests again after a placement's retries ran out.
- Banner and native slots left empty by no-fill try again when the app returns to the foreground.

### Known limits

- At narrow widths or large text scales, native templates can truncate headline and body text below AdMob's minimum character counts. Test your screens before release; see [Native ads](doc/native-ads.md#policy-and-production-limits).

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
