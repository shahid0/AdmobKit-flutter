# AdmobKit API Reference

Import `package:admob_kit_flutter/admob_kit_flutter.dart`. Use the public facade, not internal pool/lease/platform APIs.

## Initialization and readiness

- `initialize(config: AdmobKitConfig(...)) → Future<void>` starts consent, ATT, SDK and native-factory registration. Await/catch failures. Calls share the current initialization; dispose before replacing configuration.
- `initializationState` / `initializationStateListenable` expose `uninitialized`, `gatheringConsent`, `initializingSdk`, `ready`, `consentDenied`, `failed`, `updatingConsent`, `disposed`.
- `canRequestAds → bool` is a snapshot, not a settled decision. Never use it as an early guard that skips initial loads while startup is resolving.
- `waitUntilCanRequestAds() → Future<bool>` awaits current resolution. Call initialize first; it does not implicitly boot.
- `registerPlacements(list, {placementCapacities}) → void` registers when IDs resolve; can be called during initialization. Banner registration does not guess width.
- `waitFor(placement, {timeout, bannerLayout}) → Future<bool>` waits for initialization/privacy resolution, then ad readiness/failure/timeout. Timeout applies to the ad wait, not consent/SDK resolution.
- `preload(placement, {bannerLayout}) → Future<void>` awaits on-demand preload completion, not a readiness boolean; use `waitFor` when a decision is needed.
- `isReady`, `isLoading`, `getState`, `watchState` accept `{bannerLayout}`. State queries are snapshots/streams, not startup barriers.
- Explicit banner preload/readiness/state calls require `BannerLayout(width: logicalWidth, orientation: BannerOrientation.portrait)` (or `.landscape`). Widgets resolve this themselves.

## Presentation

- `show(FullscreenPlacement, {onDismissed, onDisplayed, onRewardGranted}) → void`: synchronous non-waiting request. Unready/blocked/premium calls dismiss immediately. Native placements, including fullscreen templates, use widgets, not show.
- `isShowingAd → bool` includes SDK fullscreen ads and active loaded fullscreen-native ownership. It does not detect arbitrary app dialogs or paywalls; app policy must gate those separately.
- `AdBannerView(placement:, active: true)` uses bounded parent width and MediaQuery orientation, then SDK-resolved height. No fixed height argument.
- `AdNativeView(placement:, active: true, placeholder:, showPlaceholder: true)` reserves a loading estimate, then sizes to native-measured assets. No template/width/height override on the widget.
- `AdPaywallGuard(placement:, onDismiss:, builder:)` unifies close and hardware back.
- `showPrivacyOptionsForm() → Future<bool>` presents privacy options and resolves the updated session gate.
- `openAdInspector([onComplete])` opens SDK QA tools.
- `dispose()` ends the session and releases resources.

## Placements

All constructors accept `id`, `androidId`, `iosId`, `priority`, `loadOnce`, `isSplash`.
IDs identify immutable configuration; use different IDs for different templates/sizing/unit IDs.

- `InterstitialPlacement`, `AppOpenPlacement`, `RewardedPlacement`, `RewardedInterstitialPlacement`.
- `BannerPlacement(sizing: BannerSizing.anchoredAdaptive())` (default) or `BannerSizing.inlineAdaptive(maxHeight:)`.
- `NativePlacement(template: NativeAdTemplate.cardContentTop, style: NativeAdStyle())` (defaults).
- `loadOnce: true` stops background replenishment after consumption. New inline demand may load again; this is not an install-level impression limit.
- Test unit IDs: `AdMobTestIds.interstitialAndroid`, `.bannerIos`, `.nativeAndroid`, etc.

## Native catalog and styling

| Template Family | Canonical Preset | Loading estimate (logical px) | Semantic Variants |
| --- | --- | --- | --- |
| **Card** (3) | `NativeAdTemplate.stackedCard` | 132 | `cardContentTop`, `cardActionTop`, `cardContentTopTrailingIcon` |
| **Feed Card** (3) | `NativeAdTemplate.feedCard` | 340 | `feedMediaFirst`, `feedContentFirst`, `feedActionMiddle` |
| **Fullscreen** (3) | `NativeAdTemplate.fullscreen` | Fill bounded parent, min 320 | `fullscreenMediaFirst`, `fullscreenContentFirst`, `fullscreenActionMiddle` |

All require bounded width >=320. Inline height is measured from SDK assets, width and Flutter text scale; `placement.template.height` is a loading estimate, not a fixed-height constraint. Supplied icons/video remain visible; optional missing assets collapse. Headline and CTA wrap when needed. Optional body appears on one line only if its complete text fits; otherwise it is omitted. Names describe stable asset order: content means the icon/copy identity, action means CTA. Cards retain video after identity; `cardActionTop` keeps its CTA first. Feed and fullscreen share three orders but use different height contracts. Optional asset absence may make layouts converge; do not add blank space to distinguish them. Fullscreen hosts also need bounded height >=320 with sufficient space for copy/media; don't mount them directly in a scrolling axis. There is no built-in close button. Keep app dismissal outside SDK assets. Use `active:` for retained pages whose selected index is app-owned; Flutter Visibility/TickerMode and app lifecycle are also honored. No viewport detector is installed.

`NativeAdStyle` contains nullable unsigned ARGB ints: `background`, `headline`, `body`, `callToActionBackground`, `callToActionText`.
It also accepts `double? callToActionCornerRadius`: finite, non-negative logical pixels; 0 is square, null inherits, and values above half the CTA height clamp to a pill. The native default radius is 8 logical pixels. Radius does not alter dimensions or click regions.
Precedence: per-placement override → global style → native defaults. `body` also styles advertiser/rating/price assets.

- Initial global style: `AdmobKitConfig(nativeStyle:)`.
- Initial placement style: `NativePlacement(style:)`.
- Live replacement: `await AdmobKit.setNativeStyle(style, placement: placement)`; omit placement for global defaults. Updates pending/cached/displayed ads without reloading.
- `const NativeAdStyle()` resets that scope to inheritance. Calls replace overrides, not merge them. Catch platform failures; don't assume an update succeeded before awaiting it.

## Configuration

`AdmobKitConfig`: `placements`, `requestConsent`, `isPremium`, `initialConcurrency`, `subsequentConcurrency`, `placementCapacities`, `adTtl`, `analytics`, `diagnostics`, `logLevel`, `timeouts`, `testDeviceIds`, `consentTestConfig`, `initializeNativeGma`, `nativeStyle`.
Defaults include concurrency 1 and TTL 50 minutes. Retained inline ads are revalidated on reactivation, not replaced while being viewed. Rebuild hosts when premium entitlement changes; the callback is not a subscription.

Placement state: `unloaded → loading → ready → leased/consumed → unloaded`, or `loading → error`.
