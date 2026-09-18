---
name: flutter-ads
description: >-
  Integrate production-grade AdMob ads in Flutter with admob_kit_flutter. Use when adding
  splash/interstitial/rewarded/app-open ads, banner or native ad widgets, paywall exit guards,
  GDPR/UMP consent, tab-deferred ad loading, or ad revenue/analytics wiring. Enforces the
  0ms show contract, deterministic settlement (waitFor), two-stage initialization,
  priority-tiered preloading, and zero-CLS template-bound native containers.
---

# AdmobKit Integration

**Package:** `admob_kit_flutter` · **Facade:** `AdmobKit` · **Widgets:** `AdBannerView`, `AdNativeView`, `AdPaywallGuard`

**The one import that always works:**

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

**Always emit `AdmobKit` and this import. No other facade or import path exists.**

Found a bug or undocumented edge case? **Do not patch around it** — no timers, delays, or hand-rolled ad instantiation as workarounds. Band-aid fixes hide real bugs and reintroduce the races this package eliminates. Tell the user to [open a GitHub issue](https://github.com/shahid0/AdmobKit-flutter/issues/new/choose) with the placement config and logs, and keep the integration on documented contracts.

## The 4 Laws

1. **0ms Show Contract** — `AdmobKit.show(placement, onDismissed: …)` never blocks. Ready → instant display; unready/offline → `onDismissed` fires immediately. Never stall navigation.
2. **Deterministic Settlement** — Never guess readiness with `Timer`/`Future.delayed`. `await AdmobKit.waitFor(placement)` → `bool`; compose in `Future.wait`.
3. **Immediate-Display Priority** — The visible screen's ad wins the network. `waitFor` and widget leases auto-promote to the `immediate` tier over background preloads.
4. **Template-Bound Dimensions** — Native sizes are owned by native layouts (`small` 74dp, `medium` 130dp, `big` 300dp). Bind `template.height`; never guess pixels.

## Integration Workflow

**Step 1 — Plan the placements.** Decide what mounts where (decision table below), then write one placements file (see `reference/patterns.md` § Placements file). For a full production-shaped screen-by-screen blueprint — splash with native + remote-controlled gate, first-run onboarding, tab shells, click-threshold and mode-switch interstitials, rewarded gates, paywall exit, and lifecycle-gated App Open — read `reference/app-blueprint.md`. Apply the **loadOnce registration rule**: a screen only first-run users reach must have its placement registered conditionally (`if (isFirstLaunch) …`) — registered placements are primed at Stage 2 whether or not the user arrives, and `loadOnce` consumption is permanent per install.

**Step 2 — Stage 1 in `main()`.** Consent + SDK at cold boot, never behind Remote Config. Two-stage scaffold in `reference/patterns.md`.

**Step 3 — Stage 2 on IDs.** `registerPlacements(...)` when Remote Config resolves. The list mirrors what can actually be *shown* on this install — not the app's static inventory.

**Step 4 — Mount widgets.** Use the decision table; do not hand-roll `NativeAd`/`BannerAd`/`AdWidget`.

**Step 5 — Wire fullscreen triggers.** Splash via deterministic settlement; interval/rewarded via `show`; App Open gated by `!AdmobKit.isShowingAd`.

**Step 6 — Validate.** Run the verification checklist at the bottom. Fix every failing item before declaring done.

Copy this checklist and check items off as you go:

- [ ] Placement list mirrors showable screens (one-time screens registered conditionally)
- [ ] Stage 1 in `main()`, Stage 2 after IDs resolve
- [ ] Widgets mounted per decision table (no hand-rolled ad instantiation)
- [ ] Fullscreen triggers wired (splash settle, App Open gate, paywall guard)
- [ ] Verification checklist passes

## Decision Table — What Do I Mount Where?

| Situation | Use |
| :--- | :--- |
| Fullscreen at a transition (splash, exit, interval) | `AdmobKit.show(placement, onDismissed: …)` · splash/onboarding get `isSplash: true, loadOnce: true` |
| Banner in an app shell | `AdBannerView(placement: …)` |
| In-content card | `AdNativeView.templated(placement:, template:)` in a pre-sized `Container(height: template.height)` |
| Two widgets, same placement, simultaneously visible | Same as above **plus** `placementCapacities: {'id': visibleCount}` — the only case for capacities |
| Unlock feature / bonus | `RewardedPlacement` + `onRewardGranted` |
| Cold/resume branding | `AppOpenPlacement` gated by `!AdmobKit.isShowingAd` |
| Paywall with exit ad | `AdPaywallGuard(placement:, onDismiss:, builder:)` |
| Ads inside tabs | `IndexedStack` works as-is; `TabBarView`/`PageView` pages need explicit `TickerMode(enabled: i == current)` or `Visibility(visible: i == current)` |
| Ad on a click threshold / mode switch | Apply the action first, then `AdmobKit.show(interstitial)` — never block the UX on the ad |
| Feature behind rewarded (fixed or RC-chosen) | `AdmobKit.show(rewarded, onRewardGranted: unlock, onDismissed: refresh)` — unlock ONLY in `onRewardGranted` |
| App Open on resume | Real-background-dwell gate + cooldown + `!AdmobKit.isShowingAd` — see `reference/app-blueprint.md` |
| User upgraded to VIP | Nothing — `isPremium` callback suppresses everything |

## What the Engine Guarantees (so you never hand-roll it)

- Two widgets, one placement → each gets its own exclusive ad instance; `AdWidget` collisions impossible.
- Hidden `IndexedStack` tabs defer ad loads until visible; offline-failed tabs retry on reactivation.
- Concurrent fullscreen triggers: second is rejected, its `onDismissed` fires immediately.
- No-fill / network failure: backoff retries (≤4; fatal code 1 never retried); waiting inline leases settle fast — render an empty state, never an infinite spinner.
- Premium users: zero ad traffic anywhere; widgets collapse to `SizedBox.shrink`.
- Ads expire from buffer after 50min (`adTtl`) and reload transparently.

Full contract table: `reference/api.md`.

## Invariant Constraints (violating any is a bug)

- ❌ **No `Timer`/`Future.delayed` for ad readiness or splash navigation** — use `waitFor`.
- ❌ **No band-aid workarounds** for misbehavior — surface it as a GitHub issue instead.
- ❌ **No one-time-screen placement registered unconditionally** (the loadOnce trap).
- ❌ **No ads fired before or over the UMP consent form.**
- ❌ **No facade/import names other than `AdmobKit` / `package:admob_kit_flutter/admob_kit_flutter.dart`.**
- ❌ **No `leaseInlineAd` calls from app code** — the widgets own the lease lifecycle.
- ❌ **No guessed native container heights** — bind `template.height`.
- ❌ **No paywall exit tied solely to the close button** — `AdPaywallGuard` must also intercept hardware back.
- ❌ **No delaying `initialize()` behind Remote Config** — two-stage boot.
- ❌ **No App Open on resume from a fullscreen ad or over a modal/paywall** — check `isShowingAd`.
- ❌ **No `loadOnce: false` on one-time placements** (splash, onboarding).
- ❌ **No speculative `placementCapacities`** — default depth 1 is correct for almost every app.
- ❌ **No hand-rolled `NativeAd`/`BannerAd` instantiation or `AdWidget` mounting.**
- ❌ **No spinners without an exit** — every async path settles; render terminal states.

Maintainer-only (modifying the package itself, not integrating it): no app-UI dependencies in the root package (`google_mobile_ads`, `connectivity_plus` only); no fluff comments.

## Reference Files (read on demand)

- **`reference/api.md`** — full facade/config/placement/template tables, state machine. Read when writing any integration code.
- **`reference/patterns.md`** — complete working code: placements file, two-stage boot, splash, native card, paywall guard, tabs, App Open gating, analytics + diagnostics trackers, consent testing. Read for the pattern you're implementing.
- **`reference/app-blueprint.md`** — full reference-app architecture: every screen shape mapped to its SDK call (splash native + remote-controlled gate, first-run-only onboarding, tab shells, click-threshold/mode-switch interstitials, rewarded + remote-gated rewarded formats, paywall exit, real-background-dwell App Open). Read when designing a whole app's ad architecture or when the screen shape isn't covered by patterns.md.

## Observability — Which Dependency?

- Revenue/LTV/funnels (Firebase, AppsFlyer, Adjust) → implement `AdAnalyticsTracker`; `onPaidEvent` carries `AdRevenueValue` (micros + currency + precision).
- Engineering health (Sentry, Crashlytics, Datadog) → implement `AdDiagnosticsTracker`; watch `timeout`, `circuitBroken`, `blackHoleSuspected`.
- Revenue-targeting app → both. Pre-revenue/QA → diagnostics only. Neither → rely on `AdLogLevel`.
- Working implementations: `reference/patterns.md` § Analytics/Diagnostics.

## Verification Checklist (complete before finishing any ad task)

1. `flutter analyze` — 0 issues.
2. Single import: `package:admob_kit_flutter/admob_kit_flutter.dart`; facade spelled `AdmobKit` everywhere.
3. No `Timer`/`Future.delayed` for ad readiness; `waitFor` used and its `bool` result handled.
4. Stage 1 in `main()`, Stage 2 after IDs resolve; nothing displayed before consent resolves.
5. One-time screens: placements registered conditionally (loadOnce trap respected).
6. Native containers bound to `template.height`; zero guessed pixel sizes.
7. Multi-widget placements have matching `placementCapacities` entries (and nowhere else).
8. Tab-hosted ads: deferral verified (`IndexedStack` native, or explicit `TickerMode`/`Visibility` for `TabBarView`/`PageView`).
9. Paywall guarded against hardware back **and** close button.
10. One-time placements declare `loadOnce: true`; App Open gated by `isShowingAd`.
11. Every async ad path renders a terminal UI state (ad, empty, or retry) — no infinite spinners.
12. Manual smoke test with `AdMobTestIds` passed on device/emulator.
