# Design Decisions

This page records why AdmobKit works the way it does.
Each entry states the decision, the reason behind it, and what it means for your app.
Read it before proposing a change to the package, or when you need to explain a behavior to your team.

## Principles

### 1. A small, simple API; the package owns the hard parts

Apps call `initialize`, `registerPlacements`, `show`, `waitFor`, `waitForAll`, and mount `AdBannerView` or `AdNativeView`.
Everything else (consent, queueing, retries, caching, freshness, presentation ownership) happens inside the package.

**Why:** most ad bugs come from lifecycle code that every app rewrites by hand: retry loops, visibility tracking, "is an ad already showing" flags, reload-on-return logic. When the package fixes a problem once, no app has to fix it again.

**For you:** do not add your own loading controllers, retry loops, refresh timers, or visibility tracking around AdmobKit calls.

### 2. Every public API exists for a specific use case

Each method has a use case and a reason, documented in [Best practices](best-practices.md) and the [API reference](api.md).
Options such as `timeout`, `priority`, `loadOnce`, and `placementCapacities` are tools for particular situations, not settings to turn on by habit.

**Why:** an API that is used for the wrong reason produces the bugs it was meant to prevent. For example, a timeout used as a safety net cuts off ads that would have arrived, and a `priority: immediate` on a preload blocks the ad the user is actually waiting for.

### 3. The package decides only what correctness or AdMob policy requires

Product choices belong to your app: how often transitions show an ad, whether an app-open ad shows on a given resume, which screens get ads.
The package does not override them unless a choice would be a real bug or would break an AdMob policy.

**Why:** a package that makes product decisions surprises the people using it. An earlier version skipped app-open ads after the user returned from tapping an ad. That is not a policy violation, so the choice was handed back to apps.

### 4. The package does not invent problems it cannot prove

Behavior is changed for confirmed bugs, measured waste, or documented policy, not for theories.

**Why:** an unproven workaround adds code and side effects for every app. For example, whether a banner under a covering route keeps refreshing is decided by Google's SDK and the Flutter plugin. Every Flutter app that mounts an `AdWidget` behaves the same way, and Google's guidance does not ask apps to unmount banners on navigation. If that is ever a problem, the fix belongs in the plugin.

## Waiting and presenting

### 5. `waitFor` is deterministic; `timeout` is a time budget

`waitFor` settles on its own: `true` when the ad is ready, `false` when it definitively cannot come (consent denied, offline, retries exhausted, premium user, disposal).
`timeout` is optional.

**Why:** the caller of `waitFor` usually needs the ad, so cutting the wait short with an arbitrary number only loses ads. A timeout is for one situation: you know how much time you have. For example, the user is doing a task that takes about ten seconds, and the ad should be ready when they finish. That estimate is your timeout.

**For you:** call `waitFor(placement)` without a timeout unless you have a real time budget.

### 6. `waitForAll` prepares a whole funnel step

`waitForAll` awaits several placements as one step and settles when every ad is ready or unavailable.

**Why:** some steps need several ads at once. A splash screen can prepare onboarding before letting the user in, and onboarding can have three ads: a fixed banner or native ad, a fullscreen native page, and an exit interstitial. Waiting for them together means the user never reaches an empty slot. Ads that load stay buffered for the next step either way.

### 7. Offline means "not now", never "wait"

While the device is offline, the load queue pauses and `waitFor` returns `false` at once. Queued loads resume when the network returns. Cached fullscreen ads still show offline.

**Why:** waiting cannot produce an ad without a network. A device test with no network once held the splash screen for 70 seconds, because the wait and the following `show` each sat out a full timeout.

### 8. A missed splash or one-time moment is over

When a splash wait fails, its load is dropped, so the following `show` continues at once instead of waiting again.
When the widget for a `loadOnce` or splash ad leaves the screen before its ad arrives, the pending load is dropped and the placement counts as used.

**Why:** these ads belong to one moment. Loading them later, for example when the network returns after the user reached the home screen, wastes requests at top priority for screens nobody will see again.

### 9. `show` never waits for a download

`show` presents an ad that is already in memory, or calls `onDismissed` immediately if none is ready.
The exception is a splash placement whose load is already in flight: `show` can wait for that load.

**Why:** a transition must never stall on the network. Your navigation lives in `onDismissed`, which always runs, whether the ad showed, failed, or was unavailable.

### 10. One fullscreen ad owns the screen at a time

A presentation lock allows one fullscreen ad (interstitial, rewarded, app open, or fullscreen native) at a time. A `show` call while another ad owns the screen calls `onDismissed` at once.

**Why:** stacked fullscreen ads trap users and break AdMob policies. Ownership is a correctness rule, so the package enforces it.

A fullscreen native ad owns the screen only while more than half of it is inside every enclosing viewport. `TickerMode` and `Visibility` stay true for a `PageView` page that was swiped away and kept alive, so on their own they let an off-screen page hold the lock and block every later `show`. Measuring against the scroll position needs no app code; the more-than-half rule hands ownership cleanly from one page to the next mid-swipe.

### 11. Rewards come only from `onRewardGranted`

**Why:** `onDismissed` runs when the user skips the ad or no ad is available. Granting a reward there gives rewards for nothing.

## Loading and buffering

### 12. Registration preloads; register only reachable screens

`registerPlacements` starts preloading fullscreen, native, and fixed banner placements right away.

**Why:** an ad that is ready before its screen opens shows instantly. The cost is that every registered placement makes a request, and a loaded ad that is never shown lowers your show rate. Only your app knows which screens this user can reach, so registration is your decision.

### 13. Priorities follow when the user needs the ad

The queue serves `immediate`, `splash`, `high`, `medium`, then `low`, in order within each tier. `waitFor` and mounted widgets move their request to the front.

**Why:** the ad the user is waiting for must load first. `immediate` is reserved for that, and the package sets it. A preload marked `immediate` by hand takes the loading slot from the screen that is actually waiting.

### 14. One download at a time by default

`initialConcurrency` and `subsequentConcurrency` default to 1.

**Why:** on slow and cellular networks, several parallel ad downloads congest the radio and cause latency spikes and timeouts. One download at a time gives the ad the user is waiting for the whole connection. Raise `initialConcurrency` when you gate a funnel at startup on fast networks.

### 15. Recurring placements keep one spare

After a recurring placement delivers an ad, the package loads one replacement (the placement's capacity, default 1). `loadOnce` turns this off.

**Why:** the next screen or display for that placement shows instantly instead of waiting about a second. One-time moments such as onboarding use `loadOnce`, so they do not load spares nobody will use.

### 16. Fixed banners preload; adaptive banners load on layout

**Why:** an adaptive banner's size depends on the measured width and orientation, which only exist once its widget lays out. A fixed banner's size is known up front, so it can be ready before its screen opens.

**For you:** choose a fixed size when a banner must be instant. Adaptive banners cannot be passed to `waitForAll`.

### 17. Each ad goes to exactly one visible widget

Flutter's own signals, `TickerMode` (covered routes) and `Visibility` (hidden `IndexedStack` tabs), decide two things only: when a widget makes its first request, and which widget receives a returning ad. A widget that became hidden while waiting is skipped, and the ad stays buffered for it.
There is no `active` parameter.

**Why:** when several widgets share a placement, for example in lazy lists or tabs, scrolling or switching tabs used to deliver an ad to a widget the user could not see, or to two widgets at once, which crashed with "This AdWidget is already in the Widget tree". Delivering to one visible widget at a time fixes both. Flutter already reports visibility, so a manual parameter only gave apps a way to get it wrong.

### 18. A delivered ad stays with its widget

Once a widget has its ad, nothing hides, reloads, or replaces it while the widget lives. Covered routes, tab switches, and scrolling keep the same ad, and lazy list or page items holding an ad stay alive when scrolled away.

**Why:** tearing down a delivered ad and requesting again wastes a request and the impression it already earned, and makes the slot flicker.

### 19. Only unshown ads expire

Loaded ads that were never shown are replaced after `adTtl` (50 minutes by default, inside Google's freshness window). Shown ads are never discarded for age.

**Why:** an unshown ad that is too old may not earn an impression, so replacing it is correct. A shown ad already has its impression, and banners refresh through AdMob while visible.

### 20. Retries are automatic, paced, and finite

Network errors back off exponentially with jitter. No-fill retries wait longer. An invalid request (error code 1) is never retried, because it is a configuration error. After the retries run out, a later `waitFor` or `show` requests again, and an empty banner or native slot tries again when the app returns to the foreground.

**Why:** fast retry loops hammer AdMob and drain batteries. Recovery happens on real events (a new request from the app, the app resuming), not on guessed timers.

## Consent, entitlement, and appearance

### 21. Consent comes first

No ad is requested before Google UMP consent resolves. Opening the privacy options form rebuilds the ad engine.

**Why:** ads must follow the user's current consent. Ads cached under the previous choice are discarded so none is shown against the user's wishes.

### 22. Premium is one synchronous callback

`AdmobKitConfig(isPremium:)` is checked at every request and presentation.

**Why:** one source of truth removes premium checks scattered across the app. When entitlement changes, rebuild your widgets; ad widgets collapse for premium users.

### 23. Loading placeholders are honest and quiet

Reserved ad space shows a shimmering "Loading ad" placeholder that uses your color scheme, holds still under reduced motion, and is announced to screen readers. Anchored banners reserve no space, so they show nothing until loaded.

**Why:** a spinner draws attention to waiting; a soft shimmer labeled as an ad tells users what will appear without pretending to be content.

### 24. Banners fit the creative they actually show

A banner's host takes the size the SDK rendered, not the slot it requested. On rotation or width changes, the current banner stays on screen until the new size arrives.

**Why:** anchored requests can return shorter creatives, which left blank bands, and replacing a banner on resize collapsed the slot and shifted the layout.

## Documentation

### 25. No claims we cannot back up

Docs describe behavior the code guarantees and numbers that were measured. They make no promises about revenue, fill, or presentation latency.

**Why:** an SDK's latency and fill depend on Google's servers and the user's network, not on this package.
