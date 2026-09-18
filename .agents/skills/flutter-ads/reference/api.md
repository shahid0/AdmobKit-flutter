# AdmobKit API Reference

Emit exactly these names. Import: `package:admob_kit_flutter/admob_kit_flutter.dart`.

## Facade

| Call | Returns | Contract |
| :--- | :--- | :--- |
| `AdmobKit.initialize(config: AdmobKitConfig(...))` | `Future<void>` | **Stage 1** in `main()`: UMP/ATT consent + GMA SDK. Call once. |
| `AdmobKit.registerPlacements(list, {placementCapacities})` | `void` | **Stage 2** when IDs resolve. Callable repeatedly. Register conditionally for one-time screens. |
| `AdmobKit.show(placement, onDismissed:, onDisplayed:, onRewardGranted:)` | `void` | Fullscreen only (compile-time enforced). 0ms or pass-through. |
| `AdmobKit.waitFor(placement)` | `Future<bool>` | `true` ready · `false` failed/timeout/premium. Promotes to immediate tier. |
| `AdmobKit.isReady(placement)` / `isLoading(placement)` | `bool` | Buffer snapshot / in-flight download. |
| `AdmobKit.getState(placement)` | `AdPlacementState` | `unloaded · loading · ready · error` |
| `AdmobKit.watchState(placement)` | `Stream<AdPlacementState>` | Reactive transitions for custom loading UIs. |
| `AdmobKit.preload(placement)` | `void` | Manual top-up; no-ops if capacity already satisfied. |
| `AdmobKit.isShowingAd` | `bool` | Fullscreen on screen — gate App Open re-entry with this. |
| `AdmobKit.showPrivacyOptionsForm()` | `Future<bool>` | GDPR settings (wire in app Settings). |
| `AdmobKit.openAdInspector(onComplete)` | `void` | QA: native Ad Inspector. |

`leaseInlineAd` is package-internal (the widgets call it). **Never call it from app code.**

## Placements

All `const`; declare once in a `SampleAds`-style class.

```dart
InterstitialPlacement(id:, androidId:, iosId:, priority:, loadOnce:, isSplash:)
AppOpenPlacement(...)  ·  RewardedPlacement(...)  ·  RewardedInterstitialPlacement(...)
BannerPlacement(...)   ·  NativePlacement.big(...) / .medium(...) / .small(...)
```

- Defaults: interstitial/app-open → `AdPriority.high` (`splash` if `isSplash`); banner/native/rewarded → `medium`. Override with `priority:`.
- `loadOnce: true` for one-time placements (splash, onboarding) — prevents auto-replenishment after consumption.
- Test unit IDs: `AdMobTestIds.interstitialAndroid`, `.bannerIos`, `.nativeAndroid`, etc. Use them in dev.

## AdmobKitConfig fields

`requestConsent (true)` · `isPremium (() => bool)` · `initialConcurrency (1)` · `subsequentConcurrency (1)` · `placementCapacities (Map<String,int>)` · `adTtl (50min)` · `analytics` · `diagnostics` · `logLevel` · `timeouts` · `testDeviceIds` · `consentTestConfig` · `initializeNativeGma (true)`

## Native templates

| Template | Height | Native factory ID |
| :--- | :--- | :--- |
| `NativeAdTemplate.small` / `NativePlacement.small` | 74dp | `smallNativeAd` |
| `NativeAdTemplate.medium` / `NativePlacement.medium` | 130dp | `listTileMedium` |
| `NativeAdTemplate.big` / `NativePlacement.big` | 300dp | `bigNativeAd` |

## State machine

```
unloaded → loading → ready → (leased/consumed) → unloaded
                └→ error (fatal AdMob code / circuit breaker)
```
