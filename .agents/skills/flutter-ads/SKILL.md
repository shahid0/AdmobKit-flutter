---
name: flutter-ads
description: Integrate AdmobKit ads into Flutter apps through its public API. Use for startup, transitions, rewards, native layouts, adaptive banners, privacy settings, or ad diagnosis.
---

# AdmobKit app integration

Use `package:admob_kit_flutter/admob_kit_flutter.dart`.
This skill is for app integration, not package-engine maintenance.

## Start from the use case

1. Identify the app action or layout that needs an ad.
2. Select the matching recipe in [Use cases](reference/recipes.md).
3. Check method results and options in [Public API](reference/api.md).
4. Use the public facade and package widgets. Do not add a parallel ad-loading controller.

The supported sequence is initialization, reachable placement registration, then presentation or widget mounting.
The app owns navigation, rewards, purchase state, remote configuration, screen reachability, and frequency policy.
The package owns consent resolution, ad loading, retries, freshness, exclusive instances, and presentation ownership.

## Select the public operation

- Normal transition: `show`, with the normal action in `onDismissed`.
- Startup or a feature needing an ad decision: `waitFor`, then the appropriate presentation.
- Banner or native content: mount `AdBannerView` or `AdNativeView`; do not wait for an inline instance first.
- Reward: grant only from `onRewardGranted`. Skipped ads also call `onDismissed`.
- Fullscreen native: use a fullscreen native template with `AdNativeView`, not `show`.
- Privacy settings: use `isPrivacyOptionsRequired` and `showPrivacyOptionsForm`.
- Appearance: use `NativeAdStyle` and await `setNativeStyle`.

Registration can occur during initialization. It cannot occur before initialization starts.
Resolve remote-selected placement identity before calling `waitFor` for it.
`waitFor` already waits for eligibility. Do not skip it because `canRequestAds` is currently false.

Normal `show` calls do not wait for downloads. Splash calls can wait for an existing load.
There is no guaranteed zero-millisecond SDK presentation time.
A ready result does not reserve an ad or the display lock. Keep app continuation in the presentation callback.

## Layout and ownership

Read [Native ads](reference/native-ads.md) when selecting a template or changing style.
Native hosts require bounded width >=320 logical pixels. Inline height follows measured content.
Fullscreen hosts need bounded height and sufficient asset space; keep navigation outside ad assets.
Pass `active` for retained or lazy pages whose selection is app-owned.
Do not infer viewport visibility from mounting or manage ad instances and presentation locks in app code.

The native templates have an unresolved protected-copy truncation limit.
Do not declare them production-compliant from layout tests or previews. Explain the limit when native ads are in scope.

## Setup and diagnosis

Read [Platform setup](reference/setup.md) for app IDs, consent messages, ATT, and test devices.
Read [Troubleshooting](reference/troubleshooting.md) for missing ads, status, or platform errors.
Status queries support diagnosis; they are not an alternative loading sequence.

These references explain supported integration without internal source inspection.
During app integration, do not import package `src/` files, test harnesses, pools, queues, or SDK drivers.
If a supported flow still fails after public diagnosis, report the evidence as a package defect.
Inspect or change package internals only when package maintenance is the assigned task.
