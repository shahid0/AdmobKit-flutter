# Incremental engine update

Keep the existing session/readiness pipeline, queue policies, eager pool, SDK driver, and native factory integration. Each increment must leave the package working and tested. Do not add compatibility shims or an alternate ad engine.

## Implemented: first lifecycle increment

- Presentation ownership uses acquisition tokens instead of placement IDs.
- Splash settlement does not reserve the display while loading; same-placement settlement requests are deduplicated and display ownership is checked again when ready.
- Fullscreen dismissal is idempotent; synchronous presentation failures release ownership.
- Banner/native hosts discard stale placement/session completions and invalidate leased ads when initialization is disposed, failed, denied, or updating consent.
- Both hosts accept an optional `active` gate in addition to Flutter Visibility/TickerMode. Inactive hosts unmount the platform view without creating another ad request on reactivation.
- Tests exercise the real SDK AdWidget with mocked platform transport, not a replacement widget.

Verification: 113 tests passing; flutter analyze clean; performance heuristic reports no findings. Native device behavior has not been verified by this increment.

## Implemented: adaptive banner increment

- Added `BannerSizing.anchoredAdaptive()` (default) and `BannerSizing.inlineAdaptive(maxHeight:)`.
- `AdBannerView` derives logical width from bounded parent constraints and orientation from MediaQuery; removes the obsolete fixed `height:` API.
- Explicit preload/readiness/state APIs accept `bannerLayout:`. Registration retains banners without guessing a width or issuing an unsized load. `AdmobKit.preload` now returns its completion future.
- Cache, waiters, queue state, cancellation, retries, and promotion distinguish layouts. Shared placement capacity bounds buffered variants; latest demand selects background replenishment. Consumption and analytics remain placement-scoped.
- SDK-reported inline size settles readiness; SDK refreshes update observable render dimensions without duplicate future completion or a custom refresh scheduler.
- Width/orientation changes invalidate host generations. Retained banners are checked for freshness when reactivated.
- Added same-ID configuration checks and cancellation/consent validation after asynchronous SDK size resolution.
- Raised the declared minimum Flutter version to 3.41, matching the existing TickerMode API usage; no new runtime dependency.

Verification: 128 tests passing, analyzer clean, performance heuristic clean. Platform transport is mocked in SDK/widget tests; device rendering has not been verified.

## Implemented: native appearance and retained freshness

- Added `NativeAdStyle`, global `AdmobKitConfig.nativeStyle`, initial `NativePlacement.colors`, and awaited `AdmobKit.setNativeStyle` global/per-placement replacement APIs. Five shared template slots use unsigned ARGB values; empty overrides restore inheritance.
- Generated internal Dart/Kotlin/Swift transport from `pigeons/native_appearance.dart`. Regenerate with `dart run pigeon --input pigeons/native_appearance.dart`. Pigeon 27.3.0 is pinned because 29.0.4's analyzer dependency conflicts with this Flutter SDK's pinned meta package; no dependency overrides.
- Session-owned render manifests cover pending, cached, and leased native ads. Serialized full snapshots and native revisions prevent out-of-order updates; session IDs prevent old cleanup from affecting a new lifetime. Platform update failures propagate; the next snapshot carries retained desired colors.
- Android/iOS factories apply colors on creation and update existing views on the main thread. Registries hold weak view references and preserve original template defaults for resets. The SDK still owns ad creation and rendering; no alternate platform-view engine.
- Native factories are engine-owned rather than process-global. Removed obsolete manual registration in the Android example. iOS resolves the registrar's own FlutterViewController/engine and reports an explicit registration error if unavailable.
- Managed native ads carry their original load timestamp and release render identity on disposal. Retained inline hosts replace expired ads on reactivation. Live colors do not reset freshness or trigger ad loads.

Verification: 141 Flutter tests and analyzer pass; Android debug APK builds and all three Android unit tests pass. Swift sources type-check against the installed Flutter and GMA 13.7 headers. Full iOS application build is blocked by the local CocoaPods Ruby/CPU mismatch; the existing example Pods/project also target iOS versions below the installed Xcode 27 simulator minimum. Device rendering remains unverified. The expanded catalog and fullscreen-native ownership are not implemented by this increment.

## Implemented: 20 inline native templates

- Added `small1`–`small8`, `medium1`–`medium6`, and `large1`–`large6`, adapted from the approved upstream commit with complete MIT attribution in `THIRD_PARTY_NOTICES.md`. Upstream iOS variant ordering is used consistently on both platforms; these are adapted arrangements, not pixel-identical copies.
- The placement owns template/factory identity. Removed custom factory IDs, legacy constructors, widget template/size overrides, obsolete factories, Android XML/drawables/colors, and unused XIBs. There is one native layout/asset-binding path per platform, using platform linear/stack layouts.
- Catalog heights are 112/180/360 logical pixels, including a dedicated attribution/AdChoices strip. Hosts require bounded width >=320 and sufficient height before leasing. Incompatible same-ID template replacement fails without mounting the wrong ad.
- The existing queue, initialization, lease ownership, activity gates and Pigeon live-color registry remain in use. No second ad engine or runtime dependency was added. Android factory registration now runs only through the awaited initialization path, after plugins attach.
- The existing `body` color slot includes description, advertiser, rating and price, with each asset's original color restored on reset. Removed the now-unused Android Material dependency.
- Tests cover Dart/Kotlin/Swift catalog parity, every driver factory selection, invalid bounds before requests, inactive layout, pending placement replacement, missing native assets, Android LTR/RTL bounds and media separation, plus color reset/revision handling. Robolectric tests use real Android layouts and asset registration; only the final SDK ad-binder registration is shadowed.
- Updated README and runnable example call sites; adjusted nested ad-card padding for 360px-wide example screens.

Verification: 149 Flutter tests pass; analyzer and performance heuristic are clean; seven Android unit tests pass; Android debug APK builds; Swift sources type-check against the installed SDK. Real ad rendering, accessibility font scaling, and device interaction are not yet verified. Full iOS application build retains the previously documented local CocoaPods/toolchain blockers.

## Implemented: fullscreen-native templates and ownership

- Completed the catalog with `fullscreen1`–`fullscreen5`. They fill bounded host height with a 320 × 360 logical-pixel minimum; the placement remains native and uses the existing session, pool, factory and Pigeon appearance paths. No runtime dependency or alternate engine was added.
- Native stacks share existing asset binding. Variant 3 adapts the source overlay into a separate bottom panel to leave video controls unobstructed; variant 4 splits available content height evenly. Dismissal/navigation stays outside SDK assets, demonstrated by the example app's new fullscreen menu and closeable screen.
- `PresentationMutex` emits asynchronous ownership notifications and rejects acquisition after its session is disposed. Acquisition tokens still protect against stale and duplicate release callbacks.
- A loaded fullscreen native acquires before mounting its `AdWidget`. Downloads and placeholders never own the lock. Blocked hosts retry on notifications, not timers; competing native and SDK fullscreen ads cannot own presentation together.
- Hosts release on Visibility/TickerMode/explicit activity changes, route coverage, app inactivity, detachment, disposal, and session invalidation. GlobalKey reparenting and fresh reactivation preserve leased ads. Cached pages use their container's selected index via `active`; no viewport inference was introduced.
- Expired ads reload before reactivation or delayed presentation, without replacing an ad already being seen. Ordinary inline templates do not acquire presentation ownership.
- Fixed readiness during session replacement: native hosts start demand only when the session really permits requests. Existing/new hosts distinguish resolving initialization from terminal failure/disposal, avoiding premature attempts or endless loading indicators.
- Added 19 fullscreen widget regressions plus mutex notification/disposal coverage. Android geometry tests now cover all 25 layouts, and fullscreen resizing/order checks cover 320/600 widths and 360/640/800 heights. README describes the API, activity contract and source adaptations.

Verification: 169 Flutter tests pass; analyzer and performance heuristic are clean; eight Android unit tests pass; Android debug APK builds; Swift sources type-check against installed Flutter/GMA headers. Native tests mock the SDK ad-binder boundary, and Flutter tests mock platform transport. These do not verify live SDK rendering or device interaction. Full iOS application build and accessibility/device checks remain outstanding, with the previously recorded CocoaPods/toolchain limitations.

## Implemented: gallery and integration guidance

- Replaced the fullscreen-only example menu with an on-demand gallery for all 25 native templates and both adaptive-banner modes. Catalog browsing does not register/preload the inventory. Each preview has stable placement identity and `loadOnce` demand semantics.
- Native previews expose awaited, placement-scoped live palettes and inheritance reset, with visible transport failures. Navigation controls remain outside SDK assets; insufficient native bounds render explanatory non-ad content. Banner previews let users change available width without imposing a height.
- Refreshed the bundled flutter-ads skill and all integration references: removed obsolete constructors/dimensions, corrected loadOnce semantics, documented initialization settlement, layout-aware banner requests, fullscreen activity/ownership, live colors, and premium rebuild requirements. Clarified that app modal/cooldown policy is separate from the ad mutex.
- Aligned Android's direct Google Mobile Ads declaration to 25.4.0, already resolved by google_mobile_ads 9.1.0. Documented actual requirements: Android API 24/compile SDK 36, iOS 13 deployment target, and Xcode 26.2+ for the current iOS ad SDK. A newer installed Xcode's simulator constraints do not change the SDK's published deployment minimum.
- Added five example widget tests covering catalog demand/navigation, every template preview at phone bounds, insufficient width, live color/reset/error behavior without reload, and adaptive-banner width changes. The example declares its existing Google Ads SDK as a direct dev dependency for transport tests; no runtime dependency was added.

Verification: 169 package tests plus 64 example tests (including the five new gallery tests); analyzer, skill validation, and gallery performance heuristic pass. Eight Android unit tests pass and the debug APK builds. Existing Gradle/Mockito deprecation warnings remain. Full iOS simulator build was retried and stops before compilation because the installed CocoaPods/Ruby setup is invalid. No Android device is connected. These tests use mocked ad transport, not live SDK rendering.

## Implemented: native visual redesign

- Reworked the shared Android/iOS compositions using the supplied YouTube reference: neutral outlined Ad attribution, readable two-line headlines, larger body text on media cards, separated advertiser/rating/price, rounded icon treatment and compact pill CTAs. Removed the tall CTA rails and the duplicate onboarding sponsorship heading.
- `large1` and `fullscreen1` are media-first feed compositions. Other variants retain distinct content/media/action arrangements; fullscreen3 uses a trailing icon and fullscreen4 a compact side CTA. Following the spacing revision, inline heights are 104/160/340 logical pixels and fullscreen minimum height is 320. Insets/gaps are 8; copy uses measured content height rather than fixed-height blocks. Template-bound examples and integration references were updated.
- There is no attribution/AdChoices header strip. The neutral 26 × 20 Ad badge overlays the media in media-first cards and shares the initial content/action line elsewhere. Advertiser/rating/price follow the body; absent assets collapse. SDK-owned top-right AdChoices is explicitly selected in native load options; no custom AdChoicesView is installed. Corner clearance is checked in LTR/RTL, with the media badge attached to its actual media container. No custom video, caption, menu, secondary action or click controls were added. The badge remains independent of caller color overrides.
- Added a gallery Feed / dark palette using the existing live-color API. Pool, consent, lease, presentation ownership and generated appearance transport are unchanged by the visual redesign.
- All Android layout tests now use native graphics/font measurement. Added regressions for wrapped copy, rating/price separation, missing-icon collapse and text fitting its measured bounds, plus reproducible rendered fixtures for all 25 templates and light/dark large1. Images are emitted under `android/build/reports/native-design/`; SDK creative/binder and AdChoices content remain simulated in these fixtures.

Verification: 169 package and 64 example tests pass after the compact height revision. Thirteen Android tests pass with real font metrics and 320/400px LTR/RTL asset bounds, fullscreen resizing down to 320px, media non-overlap, badge placement, SDK corner clearance and absent-metadata checks. Analyzer and performance scan pass. Swift sources type-check against installed Flutter/GMA headers. Android debug APK builds. Visual fixtures were inspected; actual SDK rendering, iOS runtime geometry and accessibility font scaling remain device-validation work, not certified by these tests.

## Implemented: CTA radius in native styling

- Replaced the unreleased colors-only model/facade with `NativeAdStyle`, `NativePlacement(style:)`, `AdmobKitConfig(nativeStyle:)` and `setNativeStyle`. No deprecated alias or second styling engine. Colors and CTA radius share per-field inheritance and complete, ordered render manifests.
- Added nullable `callToActionCornerRadius` in logical pixels. Zero is square; null restores inheritance/defaults; finite non-negative values are clamped at half the CTA height. Initial/pending/live views use the same generated Pigeon contract. Android drawable and iOS layer updates preserve button bounds, badge/AdChoices styling, SDK clicks, original ad identity and load age.
- Regenerated Dart/Kotlin/Swift transport from its schema. Added validation, zero/fractional/inheritance/reset/invalid-intent and generated-channel coverage; facade and gallery tests assert no new ad load. Android tests cover all 25 layouts, simultaneous color/radius updates, default reset, stale revisions, oversized values, invalid manifests and high-density logical pixel conversion.
- Gallery includes square/rounded CTA presets and reset; the example app defaults to an 8px CTA radius through its global native style. Public docs and integration references use the new API.

Verification: 171 package, 64 example and 16 Android tests pass. Swift sources type-check and Android debug APK builds. Performance scan is clean. Live iOS rendering is still not certified by compilation/tests.

## Implemented: Android native density preservation

- Fixed the appearance registry cloning programmatic backgrounds with `Resources`, which density-scaled already-pixel-sized template geometry a second time. Clones now preserve captured geometry and remain independently mutable. Card corners stay at 16 logical pixels through attachment, live styling and default reset; CTA customization is unchanged. No Flutter gallery wrapper or iOS layout change is needed for this Android-specific defect.
- Added regressions covering all 25 templates at 2× and 3× density, including initial attachment, successive background/CTA updates, reset and unchanged bounds. Both tests failed before the fix (32px became 64px and 48px became 144px) and pass afterward.

Verification: all 18 Android unit tests pass and the example debug APK builds. Device rendering remains part of the validation below.

## Remaining verification

1. Repair/choose a working local CocoaPods toolchain, then complete the iOS application build. System-wide Ruby/CocoaPods installation was not modified.
2. Device validation across all template families: actual test creatives, absent optional assets, rotation, larger accessibility fonts, media/AdChoices interaction, route/background transitions and appearance updates. No live-rendering or accessibility approval is implied by widget/Robolectric tests.

Version bump and publication are separate actions.
