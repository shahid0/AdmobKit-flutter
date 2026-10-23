# Best Practices and Design Decisions

This guide explains how to get the most impressions from the fewest requests, and why the package behaves the way it does.
Each rule states the decision and the reason, so you can apply it to layouts these recipes do not cover.
Imports and `AppAds` come from the [complete example](../README.md#complete-example).

## The Model in One Paragraph

Your app decides **where** ads appear and **when** a transition may show one.
The package decides **how** ads load: consent, queueing, retries, caching, freshness, and who owns the screen.
Every request the package makes should end in an impression.
A loaded ad that is never shown still counts as a request: it lowers your show rate and wastes the user's data.
Most rules below follow from that.

## 1. Register Only Reachable Placements

**Do:** call `registerPlacements` as soon as unit IDs are known, listing only placements for screens this user can reach.

**Why:** registration starts preloading every fullscreen, native, and fixed banner placement in the list.
A placement for a screen the user never opens is a request without an impression.
On a device test, a registered fullscreen native that no screen displayed cost one wasted request on every launch.

```dart
void registerForUser({required bool firstLaunch, required NativePlacement onboarding}) {
  AdmobKit.registerPlacements([
    AppAds.transition,
    AppAds.native,
    AppAds.banner,
    if (firstLaunch) onboarding,
  ]);
}
```

## 2. Pick Priorities by When the User Needs the Ad

The queue serves tiers in this order: `immediate`, `splash`, `high`, `medium`, `low`.
Within a tier, requests load in order, and promoted requests go to the front.

| Tier | Use it for | Set by |
| :--- | :--- | :--- |
| `immediate` | An ad the user is waiting for right now | The package, when you call `waitFor` or an ad widget mounts |
| `splash` | Cold-start ads | `isSplash: true` |
| `high` | The first screens after launch, normal transitions | Default for interstitial and app-open |
| `medium` | Feeds, rewards, secondary screens | Default for banners, natives, rewarded |
| `low` | Rarely visited screens | You |

**Do not** set `priority: AdPriority.immediate` on a placement.
**Why:** with one download at a time, a background preload in `immediate` takes the only slot before your splash screen asks for its ad.
On a device test this delayed the splash interstitial behind an onboarding native.
`waitFor` and mounted widgets already promote what the user is waiting for.

## 3. Keep Startup Concurrency Low Unless You Register Many Placements

`initialConcurrency` and `subsequentConcurrency` default to `1`.
**Why:** one download at a time gives the first ad the whole connection, so the ad the user waits for arrives soonest.
The cost is that later placements become ready later: on Wi-Fi each load took about one second, and the first load after a cold start took several seconds.
If you register many placements and most users are on fast networks, `initialConcurrency: 2` readies the batch sooner.

## 4. Splash: Wait With a Deadline, Then Continue

Await the splash ad together with your own startup work, and always continue in `onDismissed`.

```dart
Future<void> runSplash(BuildContext context, Future<void> appReady, VoidCallback onContinue) async {
  await Future.wait([appReady, AdmobKit.waitFor(AppAds.transition, timeout: const Duration(seconds: 5))]);
  if (!context.mounted) return;
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}
```

**Why:** `waitFor` waits for consent and SDK setup before its timer starts, then promotes the placement to the front of the queue.
Offline it returns `false` at once, and a timed-out splash wait ends the splash moment, so `show` never waits a second time. Without these rules, a device test with no network sat on the splash screen for 70 seconds.
`show` never waits for a download, so a missing ad cannot block navigation.
Use `isSplash: true` and `loadOnce: true` for a cold-start-only placement so it does not keep refilling after launch.

## 5. Transitions: Show, Never Await

Call `show` at the moment of the transition and put the navigation in `onDismissed`.
Your app owns frequency: decide in your own code how often a transition may show an ad.

**Do not** show two fullscreen ads back to back, for example a splash ad and then another when a paywall closes.
**Why:** consecutive interstitials hurt retention and can break AdMob placement policies. The package presents whatever you ask for; frequency is a product decision.

### App-Open Ads on Resume

Call `show` with your `AppOpenPlacement` when the app returns from the background.
The package skips that call, and runs `onDismissed`, when the user is coming back from an ad: a tapped banner or native ad, or a fullscreen ad that was on screen when the app left.
**Why:** an app-open ad right after the user returns from an ad they tapped is a poor experience and works against AdMob's app-open guidance. Only the package sees ad clicks, so it handles this for you. Do not add your own `isShowingAd` checks around it.

## 6. Banners: Choose the Sizing by Where the Banner Lives

| Sizing | Use it for | Loads | Why |
| :--- | :--- | :--- | :--- |
| `anchoredAdaptive()` | Sticky top or bottom bars | When its view lays out | Size depends on the measured width and orientation |
| `inlineAdaptive(maxHeight:)` | Banners inside scrolling content | When its view lays out | Same; `maxHeight` caps the creative |
| `standard()`, `mrec()`, `fixed(...)` | Banners that must be ready before the screen opens | At registration | Size is known up front, so it can preload |

- A host sizes itself to the creative the SDK actually rendered, so anchored banners do not leave blank bands.
- Use `reserveSpace` (default for inline and fixed) to stop content jumping while a banner loads.
- A fixed banner wider than its host renders nothing and requests nothing.
- AdMob refreshes a banner only while it is visible, and a mounted banner keeps its slot across routes and tabs. Do not add your own refresh timers.

### Spares and `loadOnce`

After a recurring placement delivers an ad, the package loads one spare (the placement's capacity, default 1).
The next view for that placement then shows instantly.

- Use one shared recurring placement when the same banner appears on several screens. The spare makes each new screen instant.
- Set `loadOnce: true` for a banner that appears on a single screen once. **Why:** a mounted banner refreshes itself, so a spare for a screen that never mounts a second host is a wasted request.

## 7. Native Ads: One Placement per Template, Capacity per Visible Slot

- Declare one placement per template. Hosts sharing a placement must share its template.
- Set `placementCapacities` to the number of slots that can be on screen together. **Why:** each slot leases its own ad, and capacity decides how many stay ready.
- Use `loadOnce: true` for one-time screens such as onboarding.

```dart
void registerFeed() => AdmobKit.registerPlacements(
  [AppAds.native],
  placementCapacities: {AppAds.native.id: 2},
);
```

## 8. Hidden Tabs, Covered Routes, and `active`

Ad widgets defer their **first** request until the subtree is visible: `TickerMode` (covered routes), `Visibility` (hidden `IndexedStack` tabs), and `active` must all allow it.
Once a widget holds an ad, it keeps it for its lifetime, even while a route covers it or its tab is hidden.
Inside `PageView`, `ListView`, and `TabBarView`, a widget holding an ad also keeps itself alive when scrolled away, so scrolling back shows the same ad without a new request.

**Why:** tearing down a delivered ad loses the impression in progress, makes the view flicker on return, and makes the widget request again.
An offstage subtree is not painted, so keeping the ad mounted costs nothing visible.

Pass `active` only for pages Flutter cannot detect, such as `PageView` pages:

```dart
Widget pagedNative(int pageIndex, int selectedIndex) => AdNativeView(
  placement: AppAds.native,
  active: pageIndex == selectedIndex,
);
```

This stops pages the user never swipes to from requesting ads.

## 9. Freshness

Loaded ads that were never shown expire after `adTtl` (50 minutes by default), inside Google's freshness window for loaded ads.
The package replaces them automatically.
An ad that was shown keeps its slot. Banners refresh through AdMob and natives stay until their widget leaves the tree.

## 10. Measure the Right Numbers

- `AdDiagnosticsTracker` reports network time: `REQUESTED` to `LOADED` is how long AdMob took.
- `AdAnalyticsTracker.onAdLoaded` reports time from request to ready, **including queue wait**. Use it to see how long users wait for an ad, not to measure network speed.
- Show rate is impressions (`onPaidEvent` or `onAdDisplayed`) divided by loads. If it is low, look for registered placements whose screens users do not reach, and for spares that are never used.

## Checklist

1. Register only placements for screens this user can reach.
2. Leave priorities at their defaults, use `isSplash` for cold start, and never set `immediate` yourself.
3. Splash: `waitFor` with a timeout, then `show` and continue in `onDismissed`.
4. Transitions: `show` without awaiting, with your own frequency rules, and never two in a row.
5. Banners: fixed when they must be instant, adaptive otherwise. Shared recurring placements across screens, `loadOnce` for single screens.
6. Natives: one placement per template and capacity equal to the number of visible slots.
7. Pass `active` only for pages Flutter cannot detect.
