# Best Practices

How to get the most impressions from the fewest requests with AdmobKit.
Each rule links to the reasoning in [Design decisions](design-decisions.md).
Imports and `AppAds` come from the [minimal app](../README.md#minimal-app).

Every request should end in an impression. A loaded ad that is never shown still counts as a request: it lowers your show rate and uses the user's data. Most rules below follow from that.

## 1. Register only reachable placements

Call `registerPlacements` as soon as your unit IDs are known, listing only placements for screens this user can reach. Registration preloads fullscreen, native, and fixed banner placements.

```dart
void registerForUser({required bool firstLaunch, required NativePlacement onboarding}) {
  AdmobKit.registerPlacements([AppAds.transition, AppAds.native, AppAds.banner, if (firstLaunch) onboarding]);
}
```

Reasoning: [decision 12](design-decisions.md#12-registration-preloads-register-only-reachable-screens).

## 2. Leave priorities at their defaults

| Tier | Use it for | Set by |
| :--- | :--- | :--- |
| `immediate` | The ad the user is waiting for right now | The package, when you call `waitFor` or a widget mounts |
| `splash` | Cold-start ads | `isSplash: true` |
| `high` | First screens after launch, normal transitions | Default for interstitial and app open |
| `medium` | Feeds, rewards, secondary screens | Default for banners, natives, rewarded |
| `low` | Rarely visited screens | You |

Never set `priority: AdPriority.immediate` yourself. Reasoning: [decision 13](design-decisions.md#13-priorities-follow-when-the-user-needs-the-ad).

## 3. Wait without a timeout

`waitFor` settles on its own when the ad is ready or cannot come. Pass `timeout` only when you have a real time budget, such as a task the user is doing.

```dart
Future<void> runSplash(BuildContext context, Future<void> appReady, VoidCallback onContinue) async {
  await Future.wait([appReady, AdmobKit.waitFor(AppAds.transition)]);
  if (!context.mounted) return;
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}

Future<bool> prepareWhileUserWorks(Duration estimatedTaskTime) =>
    AdmobKit.waitFor(AppAds.transition, timeout: estimatedTaskTime);
```

Reasoning: [decision 5](design-decisions.md#5-waitfor-is-deterministic-timeout-is-a-time-budget).

## 4. Prepare a funnel step with `waitForAll`

When the next step needs several ads ready, wait for them together. A splash screen preparing onboarding is the typical case.

```dart
Future<void> prepareOnboarding(VoidCallback openOnboarding) async {
  await AdmobKit.waitForAll([AppAds.native, AppAds.transition]);
  openOnboarding();
}
```

Ads load in list order, ahead of background preloads, one at a time by default. Each takes about a second on Wi-Fi, so consider `initialConcurrency: 2` if you gate a funnel at startup. Adaptive banners cannot be awaited; use a fixed size if a banner must be ready. Reasoning: [decision 6](design-decisions.md#6-waitforall-prepares-a-whole-funnel-step).

## 5. Show at transitions and continue in `onDismissed`

```dart
void completeLevel(VoidCallback openNextLevel) {
  AdmobKit.show(AppAds.transition, onDismissed: openNextLevel);
}
```

`show` never waits for a download, and `onDismissed` always runs. Decide frequency in your own code, and do not show two fullscreen ads back to back: it hurts retention and can break AdMob placement policies. Reasoning: [decisions 9 and 10](design-decisions.md#9-show-never-waits-for-a-download).

## 6. Grant rewards only in `onRewardGranted`

```dart
void offerReward(RewardedPlacement placement, VoidCallback grantReward) {
  AdmobKit.show(placement, onRewardGranted: (amount, type) => grantReward());
}
```

Reasoning: [decision 11](design-decisions.md#11-rewards-come-only-from-onrewardgranted).

## 7. Choose banner sizing by where the banner lives

| Sizing | Use it for | Loads |
| :--- | :--- | :--- |
| `BannerSizing.anchoredAdaptive()` (default) | Sticky top or bottom bars | When its widget lays out |
| `BannerSizing.inlineAdaptive(maxHeight:)` | Banners inside scrolling content | When its widget lays out |
| `standard()`, `mrec()`, `large()`, `leaderboard()`, `fixed(...)` | Banners that must be ready before the screen opens | At registration |

- Share one recurring placement when the same banner appears on several screens; its spare makes each new screen instant.
- Use `loadOnce: true` for a banner on a single one-time screen.
- Inline and fixed banners reserve their height by default and show a "Loading ad" shimmer while loading.

Reasoning: [decisions 15, 16, and 24](design-decisions.md#16-fixed-banners-preload-adaptive-banners-load-on-layout).

## 8. Use one native placement per template

- Every widget sharing a placement must use its template.
- Set `placementCapacities` to the number of slots of that placement visible at the same time.
- Use `loadOnce: true` for one-time screens such as onboarding.

```dart
void registerFeed() => AdmobKit.registerPlacements([AppAds.native], placementCapacities: {AppAds.native.id: 2});
```

## 9. Mount ads directly in tabs, pages, and lists

No parameters are needed. A widget requests its first ad when visible, a returning ad goes to a visible widget, and a delivered ad stays with its widget across routes, tab switches, and scrolling.

```dart
Widget tabWithAd() => const AdNativeView(placement: AppAds.native);
```

Keep widget keys and placements stable: a new key or placement means a new widget and a new request. Reasoning: [decisions 17 and 18](design-decisions.md#17-each-ad-goes-to-exactly-one-visible-widget).

## 10. Let the package handle offline, retries, and freshness

Do not add connectivity checks, retry loops, or refresh timers. Offline, `waitFor` returns `false` at once and queued loads resume when the network returns. Retries back off on their own, and empty slots try again when the app returns to the foreground. Reasoning: [decisions 7, 19, and 20](design-decisions.md#7-offline-means-not-now-never-wait).

## 11. Measure the right numbers

- `AdDiagnosticsTracker` reports network time: `requested` to `loaded` is how long AdMob took.
- `AdAnalyticsTracker.onAdLoaded` reports time from request to ready, including queue wait. Use it to see how long users wait for an ad.
- Show rate is impressions (`onPaidEvent` or `onAdDisplayed`) divided by loads. When it is low, look for registered placements whose screens users do not reach.

## Checklist

1. Register only placements for reachable screens.
2. Keep default priorities; use `isSplash` for cold start.
3. `waitFor` and `waitForAll` without a timeout, unless you have a real time budget.
4. `show` at transitions, continue in `onDismissed`, never two fullscreen ads in a row.
5. Rewards only in `onRewardGranted`.
6. Fixed banners when instant, adaptive otherwise; `loadOnce` for one-time screens.
7. One native placement per template; capacity equals visible slots.
8. Mount ad widgets directly; keep keys and placements stable.
9. No connectivity checks, retry loops, refresh timers, or visibility tracking.
