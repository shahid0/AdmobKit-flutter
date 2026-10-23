---
name: flutter-ads
description: Integrate Google AdMob ads into Flutter apps with the AdmobKit package (admob_kit_flutter). Use for initialization, splash and funnel ads, transitions, rewards, banners, native ads, tabs and lists, paywalls, app-open ads, premium users, privacy settings, migration from 0.0.2, or diagnosing missing ads.
---

# AdmobKit integration

Import `package:admob_kit_flutter/admob_kit_flutter.dart`. Use only the public API; never import `src/` files.
This skill is for app integration. Change package internals only when maintaining the package itself.

## How to work

1. Identify the app flow that needs an ad.
2. Pick the recipe in [Recipes](reference/recipes.md).
3. Apply the rules in [Best practices](reference/best-practices.md).
4. When a behavior seems surprising, or you want to change it, read [Design decisions](reference/design-decisions.md) first. Every public API exists for a specific use case; do not work around one.
5. Check exact signatures in the [API reference](reference/api.md).
6. Upgrading an app from 0.0.2: follow [Migrating from 0.0.2](reference/migration.md).

## The model

- The app owns: which screens get ads, when transitions show one, frequency, rewards, purchase state, and which placements are reachable.
- The package owns: consent, loading, queueing, retries, caching, freshness, offline handling, and which widget gets which ad.
- The package makes product decisions only when correctness or AdMob policy requires it.

Sequence: `initialize` once in `main`, `registerPlacements` for reachable screens, then `show` / `waitFor` / `waitForAll` and mount widgets.

## Pick the operation

| Need | Use | Why |
| :--- | :--- | :--- |
| Transition ad | `show(placement, onDismissed: next)` | Never waits for a download; `onDismissed` always runs |
| Splash ad | `await waitFor(splash)` then `show` | `waitFor` settles on its own; offline returns `false` at once |
| Several ads before the next step (e.g. onboarding prepared on splash) | `await waitForAll([...])` | Loads in list order; loaded ads stay buffered for the next step |
| Reward | `show(onRewardGranted: grant)` | `onDismissed` also runs for skipped or missing ads |
| Banner or native content | Mount `AdBannerView` / `AdNativeView` | Widgets request, size, and keep their own ads |
| Banner that must be ready before its screen | Fixed sizing (`standard`, `mrec`, ...) | Only fixed sizes preload; adaptive sizes need a measured width |
| App-open on resume | `show(appOpenPlacement)` from your lifecycle code | Which resumes show an ad is the app's decision |
| Paywall exit | `AdPaywallGuard` | One exit for close and back; starts once |
| Premium users | `AdmobKitConfig(isPremium:)` | One synchronous check used everywhere |
| Privacy entry | `isPrivacyOptionsRequired`, `showPrivacyOptionsForm` | Required by Google UMP in some regions |

## Rules

- Call `waitFor` and `waitForAll` without `timeout`. Pass one only for a real time budget, such as how long a task the user is doing takes.
- Register only placements whose screens this user can reach; registration preloads them.
- Keep default priorities. Use `isSplash` for cold start. Never set `priority: AdPriority.immediate`.
- Use `loadOnce: true` for one-time screens (splash, onboarding).
- Use one native placement per template; set `placementCapacities` to the number of its widgets visible together.
- Mount ad widgets directly in tabs, `PageView` pages, `IndexedStack` children, and lists. There is no `active` parameter; visibility is detected.
- Keep widget keys and placements stable, or the widget becomes a new widget and requests again.
- Native widgets need a bounded width of at least 320. Let inline templates size themselves. Fullscreen templates need bounded height; keep your dismiss button outside the ad.
- Adaptive banners need a bounded width or an explicit `width:`.
- Never show two fullscreen ads back to back.

## Do not

- Add retry loops, refresh timers, connectivity checks, visibility tracking, keep-alive wrappers, or `isShowingAd` guards around ads.
- Await an ad before mounting `AdBannerView` or `AdNativeView`.
- Grant rewards in `onDismissed`.
- Pass native placements or adaptive banners to `show`; pass adaptive banners to `waitForAll`.
- Call `dispose()` for screen changes or premium changes.
- Declare native templates policy-safe from previews: at narrow widths or large text scales they can truncate copy below AdMob's minimums. Say so when native ads are in scope.

## Setup and diagnosis

- Platform setup (app IDs, consent messages, ATT, test devices): [Platform setup](reference/setup.md).
- Templates and styling: [Native ads](reference/native-ads.md).
- Missing ads and errors: [Troubleshooting](reference/troubleshooting.md). Diagnose with `initializationState`, `getState`, verbose logs, and Ad Inspector.
- If a supported flow still fails after diagnosis, report it as a package defect with the evidence instead of working around it in app code.
