# Recipes

Complete, copyable integrations for common app flows.
Imports and `AppAds` come from the [minimal app](https://github.com/shahid0/AdmobKit-flutter/blob/main/README.md#minimal-app).
For the rules behind these recipes, read [Best practices](best-practices.md); for the reasoning, read [Design decisions](design-decisions.md).

| User flow | Recipe | Key API |
| :--- | :--- | :--- |
| Screen transition, completed level | [Transitions](#transitions) | `AdmobKit.show` |
| Optional reward | [Rewarded ads](#rewarded-ads) | `show(onRewardGranted:)` |
| Splash screen and cold start | [Splash](#splash) | `waitFor`, `show` |
| Prepare the next funnel step | [Funnel preparation](#funnel-preparation) | `waitForAll` |
| Sticky banner, feed banner, instant banner | [Banners](#banners) | `AdBannerView` |
| In-feed and fullscreen native ads | [Native ads](#native-ads) | `AdNativeView` |
| Tabs, pages, lists | [Tabs and lists](#tabs-and-lists) | `AdNativeView`, `AdBannerView` |
| Paywall close and back button | [Paywall exit](#paywall-exit) | `AdPaywallGuard` |
| Return from background | [App-open on resume](#app-open-on-resume) | `show(AppOpenPlacement)` |
| Remote-configured unit IDs | [Remote configuration](#remote-configuration) | `registerPlacements` |
| Ad-free subscribers | [Premium](#premium) | `AdmobKitConfig(isPremium:)` |
| GDPR privacy settings entry | [Privacy settings](#privacy-settings) | `isPrivacyOptionsRequired`, `showPrivacyOptionsForm` |
| Slow networks | [Emerging markets](#emerging-markets) | `AdTimeoutConfig.emergingMarkets` |
| Revenue and health telemetry | [Analytics and diagnostics](#analytics-and-diagnostics) | `AdAnalyticsTracker`, `AdDiagnosticsTracker` |

## Transitions

Call `show` at the moment of the transition and put the navigation in `onDismissed`.
`show` presents a cached ad or calls `onDismissed` at once; it never waits for a download.

```dart
void continueWithAd(VoidCallback onContinue) {
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}
```

Do not also navigate before calling `show`. Decide how often transitions show an ad in your own code.

## Rewarded ads

Register the reward placement before the feature becomes reachable. `RewardedPlacement` and `RewardedInterstitialPlacement` share the reward callback.

```dart
void requestFeatureReward(
  FullscreenPlacement placement, {
  required void Function(num amount, String type) grantReward,
  required VoidCallback refreshFeature,
}) {
  AdmobKit.show(placement, onRewardGranted: grantReward, onDismissed: refreshFeature);
}
```

Grant benefits only in `onRewardGranted`. `onDismissed` also runs after skipped or unavailable ads.
To enable a "Watch ad" button only when an ad can come, await `AdmobKit.waitFor(placement)` first.

## Splash

Mark cold-start placements with `isSplash: true`. Wait for the ad together with your own startup work, then continue in `onDismissed`.

```dart
const splashAd = InterstitialPlacement(
  id: 'splash',
  androidId: AdMobTestIds.interstitialAndroid,
  iosId: AdMobTestIds.interstitialIos,
  isSplash: true,
  loadOnce: true,
);

Future<void> runSplash(BuildContext context, Future<void> appReady, VoidCallback onContinue) async {
  await Future.wait([appReady, AdmobKit.waitFor(splashAd)]);
  if (!context.mounted) return;
  AdmobKit.show(splashAd, onDismissed: onContinue);
}
```

`waitFor` settles on its own. Offline it returns `false` at once, and a failed splash wait lets `show` continue immediately.

## Funnel preparation

When the next step needs several ads ready, wait for them together. Here the splash screen prepares onboarding's native ad, fullscreen native page, and exit interstitial:

```dart
const onboardingNative = NativePlacement(
  id: 'onboarding_native',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.cardContentTop,
  loadOnce: true,
);
const onboardingPage = NativePlacement(
  id: 'onboarding_page',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.fullscreenMediaFirst,
  loadOnce: true,
);
const onboardingExit = InterstitialPlacement(
  id: 'onboarding_exit',
  androidId: AdMobTestIds.interstitialAndroid,
  iosId: AdMobTestIds.interstitialIos,
  loadOnce: true,
);

Future<void> prepareOnboarding(VoidCallback openOnboarding) async {
  AdmobKit.registerPlacements([onboardingNative, onboardingPage, onboardingExit]);
  await AdmobKit.waitForAll([onboardingNative, onboardingPage, onboardingExit]);
  openOnboarding();
}
```

The ads load in list order. Ads that are ready stay buffered: the onboarding widgets show them instantly and `show(onboardingExit)` presents the interstitial. Adaptive banners cannot be awaited; use a fixed size for a banner that must be ready.

## Banners

Mount `AdBannerView` where the banner shows. It loads, sizes, and refreshes itself.

```dart
const feedBanner = BannerPlacement(
  id: 'feed_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
);

const rectangleBanner = BannerPlacement(
  id: 'rectangle_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.mrec(),
);

Widget stickyBanner() => const SafeArea(child: AdBannerView(placement: AppAds.banner));
Widget bannerInFeed() => const AdBannerView(placement: feedBanner);
Widget instantRectangle() => const AdBannerView(placement: rectangleBanner);
```

- The default sizing is an anchored adaptive banner at the parent's width. It reserves no space and loads when it lays out.
- Inline adaptive and fixed banners reserve their height and show a "Loading ad" shimmer while loading. Pass `reserveSpace: false` to collapse until loaded.
- Fixed banners (`standard`, `mrec`, `large`, `leaderboard`, `fixed`) preload when registered, so they show as soon as their screen opens. A fixed banner wider than its host shows nothing and makes no request.
- In an unbounded horizontal parent, pass `width:`; fixed banners default to their own width.

For a collapsible banner, use `BannerPlacement.collapsible(androidId: ..., iosId: ..., anchor: CollapsibleAnchor.bottom)`.

## Native ads

Mount `AdNativeView` with a bounded width of at least 320 logical pixels. Inline templates size themselves to their content.

```dart
Widget feedNative() => LayoutBuilder(
  builder: (context, constraints) => constraints.maxWidth >= AppAds.native.template.minWidth
      ? const AdNativeView(placement: AppAds.native)
      : const SizedBox.shrink(),
);
```

For a fullscreen native page, use a fullscreen template, give the host a bounded height, and keep your own dismiss button outside the ad:

```dart
Widget fullscreenNativeRoute(NativePlacement placement, VoidCallback onContinue) => Scaffold(
  body: SafeArea(child: AdNativeView(placement: placement)),
  bottomNavigationBar: SafeArea(
    child: TextButton(onPressed: onContinue, child: const Text('Continue')),
  ),
);
```

Do not pass native placements to `show`. Templates and styling are covered in [Native ads](native-ads.md).

## Tabs and lists

Mount ad widgets directly in tabs, `PageView` pages, `IndexedStack` children, and list items. No extra parameters are needed.

```dart
Widget nativePage() => const AdNativeView(placement: AppAds.native);
```

A widget requests its first ad when it is visible. A returning ad goes to a widget the user can see, and a delivered ad stays with its widget when a route covers it, its tab is hidden, or it scrolls away.
Several widgets can share one placement if they use its template. Register the placement with a capacity equal to the number of widgets visible together:

```dart
void registerFeed() => AdmobKit.registerPlacements([AppAds.native], placementCapacities: {AppAds.native.id: 2});
```

## Paywall exit

`AdPaywallGuard` routes the close button and the Android back button through one exit, showing a fullscreen ad for users who leave without buying.

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

With `isPurchased: true`, the guard closes at once without an ad. Repeated taps or back presses are ignored while the exit is in progress.

## App-open on resume

Register an `AppOpenPlacement` and call `show` from your lifecycle handler when your app decides a resume should show one:

```dart
void showResumeAd(AppOpenPlacement placement, {required bool appPolicyAllowsResumeAd}) {
  if (!appPolicyAllowsResumeAd) return;
  AdmobKit.show(placement);
}
```

Which resumes show an ad is your product decision: for example, skip cold starts handled by your splash, permission dialogs, purchase sheets, or returns shortly after another ad. The package only guarantees that an app-open ad never shows over another fullscreen ad.

## Remote configuration

Start `initialize` before remote configuration finishes, and register placements as soon as their unit IDs resolve. Registration is allowed while consent is still being collected.

```dart
Future<void> registerRemotePlacements(Future<Iterable<AdPlacement>> resolvedPlacements) async {
  AdmobKit.registerPlacements(await resolvedPlacements);
}
```

Resolve a remote splash placement before waiting for it:

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

## Premium

Pass one synchronous callback that reports the user's current entitlement:

```dart
AdmobKitConfig premiumConfig(bool Function() hasAdFreeAccess) => AdmobKitConfig(isPremium: hasAdFreeAccess);
```

Premium users get no requests and no presentations, and ad widgets collapse. When entitlement changes, rebuild your widgets.

## Privacy settings

Show a privacy settings entry only when Google UMP requires it:

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

The form cannot open over a fullscreen ad. Changing consent discards cached ads, which reload under the new choice.

## Emerging markets

On high-latency or 2G/3G networks, longer download windows avoid cutting off ads mid-download:

```dart
AdmobKitConfig emergingMarketsConfig() => const AdmobKitConfig(timeouts: AdTimeoutConfig.emergingMarkets);
```

Profiles are listed in the [API reference](api.md#timeout-profiles).

## Analytics and diagnostics

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

AdmobKitConfig trackedConfig() => AdmobKitConfig(analytics: ExampleAnalytics(), diagnostics: ExampleDiagnostics());
```

Handle your own service errors inside tracker callbacks.
