# Use Cases and Recipes

This document provides recipes for production ad integration in Flutter apps.
Imports and `AppAds` come from the [complete example](https://github.com/shahid0/AdmobKit-flutter/blob/main/README.md#complete-example).

Call `AdmobKit.initialize()` once in your app entry point.
Declare and register placements when their unit identifiers and screen routes are known.
Your app owns navigation logic and business rules.
The engine manages background loading, warm caching, retry intervals, and presentation locks.

## Recipe Decision Guide

| User Flow | Recommended Recipe | Key Public API |
| :--- | :--- | :--- |
| Screen navigation, completed level | [Normal Transitions](#normal-transitions) | `AdmobKit.show()` |
| Optional reward for user action | [Rewarded Ads](#rewarded-ads) | `AdmobKit.show(onRewardGranted: ...)` |
| Sticky screen banners | [Banners and Native Content](#banners-and-native-content) | `AdBannerView()` |
| In-feed cards matching app design | [Banners and Native Content](#banners-and-native-content) | `AdNativeView()` |
| High-latency networks (Pakistan, Ethiopia) | [High-Latency and Emerging Markets](#high-latency-and-emerging-markets) | `AdTimeoutConfig.emergingMarkets` |
| Startup and cold app open | [Startup and Remote Configuration](#startup-and-remote-configuration) | `AdmobKit.waitFor()` |
| Bottom tabs and PageViews | [Tabs and Retained Pages](#tabs-and-retained-pages) | `AdNativeView(active: ...)` |
| Paywall dismiss and hardware back | [Paywall Exit Guard](#paywall-exit-guard) | `AdPaywallGuard()` |
| App foreground from background | [App-Open Ads on Resume](#app-open-ads-on-resume) | `AdmobKit.show(AppOpenPlacement)` |
| Paid subscriber ad removal | [Premium Access](#premium-access) | `AdmobKitConfig(isPremium: ...)` |
| Mandatory GDPR / UMP settings button | [Privacy Settings](#privacy-settings) | `AdmobKit.showPrivacyOptionsForm()` |
| Revenue and diagnostic telemetry | [Analytics and Diagnostics](#analytics-and-diagnostics) | `AdAnalyticsTracker`, `AdDiagnosticsTracker` |

## Normal Transitions

Use `show` when the user completes an action and navigation must proceed immediately.
The engine shows the cached ad or executes `onDismissed` at once.
You do not need manual readiness checks or consent checks.

```dart
void continueWithAd(VoidCallback onContinue) {
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}
```

The engine calls `onDismissed` even when an ad is unavailable or skipped.
Do not execute navigation before `show` and inside `onDismissed` at the same time.

## Rewarded Ads

Register your reward placement before the reward feature becomes reachable to users.
Both `RewardedPlacement` and `RewardedInterstitialPlacement` use the same reward callback.

```dart
void requestFeatureReward(
  FullscreenPlacement placement, {
  required void Function(num amount, String type) grantReward,
  required VoidCallback refreshFeature,
}) {
  AdmobKit.show(
    placement,
    onRewardGranted: grantReward,
    onDismissed: refreshFeature,
  );
}
```

Unlock user benefits exclusively inside `onRewardGranted`.
Never unlock benefits in `onDismissed`, because `onDismissed` also runs after skipped or failed presentations.
If your user interface requires an explicit ready decision before opening, call `await AdmobKit.waitFor(placement)`.

## Banners and Native Content

Host widgets load their own ads and manage their own memory.
Mount inline widgets directly in your widget tree.
Do not await inline ads before mounting.

```dart
Widget nativeFeedItem() => const AdNativeView(placement: AppAds.native);

Widget stickyBanner() => const SafeArea(child: AdBannerView(placement: AppAds.banner));
```

Give native ads bounded width of at least 320 logical pixels.
Let content determine native ad height.
Give banners bounded width; adaptive sizing calculates the height automatically.
For a banner in a scrolling list, declare a separate placement with inline adaptive sizing:

```dart
const feedBanner = BannerPlacement(
  id: 'feed_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
);

Widget inlineBanner() => const AdBannerView(placement: feedBanner);

Widget compactInlineBanner() => const AdBannerView(
  placement: feedBanner,
  reserveSpace: false,
);
```

To collapse an inline banner until it loads, set `reserveSpace: false` on the
sizing policy or override it per host as shown above.

For a fixed banner, choose a standard size or specify positive dimensions:

```dart
const standardBanner = BannerPlacement(
  id: 'standard_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.standard(), // 320×50; reserves 50 pixels while loading.
);
const rectangleBanner = BannerPlacement(
  id: 'rectangle_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.mrec(reserveSpace: false), // 300×250; zero height until loaded.
);

Widget standardBannerItem() => const AdBannerView(placement: standardBanner);
Widget rectangleBannerItem() => const AdBannerView(placement: rectangleBanner);
```

`mrec()` is an alias of `mediumRectangle()`. Other fixed options are
`largeBanner()` (320×100), `leaderboard()` (728×90), and
`fixed(width: 468, height: 60)`. Fixed banners stay at their requested size,
centered within a wider host. Choose a size that fits the available width.
In an unbounded horizontal parent, fixed banners default to their configured
width; adaptive banners still need explicit `width`.

Only call `waitFor` on a banner when your app must prepare the exact layout before rendering.
Supply the available width and screen orientation:

```dart
Future<bool> prepareBanner(int logicalWidth, BannerOrientation orientation) => AdmobKit.waitFor(
  AppAds.banner,
  bannerLayout: BannerLayout(width: logicalWidth, orientation: orientation),
);
```

## High-Latency and Emerging Markets

In regions with high packet loss or 2G/3G mobile data (such as Ethiopia or Pakistan), video ads need longer download windows.
Short timeouts abort rich media downloads prematurely and waste user mobile data.
Supply the `emergingMarkets` profile during initialization to allocate up to 75 seconds on cellular connections:

```dart
AdmobKitConfig emergingMarketsConfig() => const AdmobKitConfig(
  timeouts: AdTimeoutConfig.emergingMarkets,
);
```

## Startup and Remote Configuration

Start initialization before remote configuration network requests complete.
Register placements as soon as remote identifiers resolve.
You can register placements while consent collection is pending.

```dart
Future<void> registerRemotePlacements(Future<Iterable<AdPlacement>> resolvedPlacements) async {
  AdmobKit.registerPlacements(await resolvedPlacements);
}
```

If your splash placement identifier comes from remote configuration, resolve that placement before waiting:

```dart
Future<void> finishStartup(
  BuildContext context, {
  required Future<FullscreenPlacement> resolvedPlacement,
  required Future<void> appReady,
  required VoidCallback onContinue,
}) async {
  final placement = await resolvedPlacement;
  AdmobKit.registerPlacements([placement]);
  await Future.wait([appReady, AdmobKit.waitFor(placement)]);
  if (!context.mounted) return;
  AdmobKit.show(placement, onDismissed: onContinue);
}
```

Set `isSplash: true` on cold-launch placements.
Set `loadOnce: true` when you do not need background replacement after the first display.

## Tabs and Retained Pages

When using `PageView`, `TabBarView`, or retained page containers, pass the selection status to `active`.

```dart
Widget nativePage(int pageIndex, int selectedIndex) => AdNativeView(
  placement: AppAds.native,
  active: pageIndex == selectedIndex,
);
```

The host widget responds to Flutter visibility signals automatically.
For fullscreen native ads, always supply the actual page activity.
The engine does not grant fullscreen presentation ownership to inactive offscreen pages.

## First-Run Screens and Shared Placements

Register first-launch placements only when onboarding is reachable.
Do not mount onboarding ad widgets for returning users.
Multiple native widgets can share one placement identifier if their template and sizing are identical:

```dart
void registerReachableAds({required bool firstLaunch, required NativePlacement onboarding}) {
  AdmobKit.registerPlacements(
    [AppAds.transition, AppAds.native, AppAds.banner, if (firstLaunch) onboarding],
    placementCapacities: {AppAds.native.id: 2},
  );
}
```

## Fullscreen Native Ads

Use a native placement with a fullscreen template and `AdNativeView`.
Do not use `AdmobKit.show()` for native ads.
Place your dismiss button outside the ad content:

```dart
Widget fullscreenNativeRoute(NativePlacement placement, VoidCallback onContinue) => Scaffold(
  body: SafeArea(child: AdNativeView(placement: placement)),
  bottomNavigationBar: SafeArea(
    child: TextButton(onPressed: onContinue, child: const Text('Continue')),
  ),
);
```

Provide bounded width and height of at least 320 logical pixels.
Only active, measured fullscreen content owns presentation.
A loading placeholder never claims presentation ownership.

## Paywall Exit Guard

Use `AdPaywallGuard` to manage modal close buttons and Android system back buttons with one trigger.
Pass subscription purchase status to `isPurchased`.

```dart
Widget guardedPaywall(FullscreenPlacement placement, VoidCallback onClose, {bool purchased = false}) => AdPaywallGuard(
  placement: placement,
  isPurchased: purchased,
  onDismiss: onClose,
  builder: (context, close) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: close, icon: const Icon(Icons.close))),
    body: const Text('Subscription options'),
  ),
);
```

If the user purchases a subscription, set `isPurchased: true`.
The guard closes the screen immediately without showing an ad.

## App-Open Ads on Resume

Register an `AppOpenPlacement`.
Call `show` from your app lifecycle handler when app policy permits:

```dart
void showResumeAd(AppOpenPlacement placement, {required bool appPolicyAllowsResumeAd}) {
  if (!appPolicyAllowsResumeAd) return;
  AdmobKit.show(placement);
}
```

Exclude cold-start duplicates, permission dialogs, and active paywalls in your policy logic.
Use `onDisplayed` to start a cooldown timer.

## Premium Access

Pass one synchronous callback to `AdmobKitConfig(isPremium: ...)` that reports current entitlement.
Do not write repetitive entitlement checks before every ad call.

```dart
AdmobKitConfig premiumConfig(bool Function() hasAdFreeAccess) => AdmobKitConfig(isPremium: hasAdFreeAccess);
```

Premium users bypass all ad requests and fullscreen presentations.
Rebuilt inline host widgets collapse automatically.
When user entitlement changes, rebuild your widget tree.

## Privacy Settings

Examine if privacy options are required after initialization starts.
Display the privacy settings button only when the platform requires it:

```dart
class PrivacySettingsTile extends StatefulWidget {
  const PrivacySettingsTile({super.key});
  @override
  State<PrivacySettingsTile> createState() => _PrivacySettingsTileState();
}

class _PrivacySettingsTileState extends State<PrivacySettingsTile> {
  late Future<bool> _required = AdmobKit.isPrivacyOptionsRequired();

  Future<void> _open() async {
    await AdmobKit.showPrivacyOptionsForm();
    if (!mounted) return;
    setState(() => _required = AdmobKit.isPrivacyOptionsRequired());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _required,
    builder: (context, result) {
      if (result.hasError) {
        return TextButton(
          onPressed: () => setState(() => _required = AdmobKit.isPrivacyOptionsRequired()),
          child: const Text('Retry privacy settings'),
        );
      }
      if (result.data != true) return const SizedBox.shrink();
      return TextButton(onPressed: _open, child: const Text('Privacy options'));
    },
  );
}
```

Do not show the privacy options form while a fullscreen ad is visible.

## Analytics and Diagnostics

Implement `AdAnalyticsTracker` and `AdDiagnosticsTracker` to record production telemetry:

```dart
class ExampleAnalytics implements AdAnalyticsTracker {
  @override
  void onAdRequested(AdPlacement placement) {}
  @override
  void onAdLoaded(AdPlacement placement, Duration loadTime) {}
  @override
  void onAdFailedToLoad(AdPlacement placement, String error, int? errorCode) {}
  @override
  void onAdDisplayed(AdPlacement placement) {}
  @override
  void onAdDismissed(AdPlacement placement) {}
  @override
  void onAdClicked(AdPlacement placement) {}
  @override
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue) {
    debugPrint('${placement.id}: ${revenue.value} ${revenue.currencyCode}');
  }
}

class ExampleDiagnostics implements AdDiagnosticsTracker {
  @override
  void onDiagnosticReport(AdDiagnosticReport report) => debugPrint(report.toString());
}

AdmobKitConfig trackedConfig() => AdmobKitConfig(
  analytics: ExampleAnalytics(),
  diagnostics: ExampleDiagnostics(),
);
```

Handle service errors inside tracker callbacks.
