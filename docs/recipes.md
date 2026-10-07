# Use cases

Each example below uses the public API. Imports and `AppAds` come from the
[complete example](../README.md#complete-example).
Initialize once before registration, waits, or widget mounting.
Declare and register placements when their unit IDs and screen reachability are known.
The app owns navigation and business rules. The library owns ad loading and presentation safety.

## Normal transitions

Use `show` when the user action must continue without waiting for a download.
No `isReady`, premium, or consent pre-check is needed.

```dart
void continueWithAd(VoidCallback onContinue) {
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}
```

The callback also runs when the library skips the ad. Do not run the same navigation
both before `show` and inside `onDismissed`. Guard repeated app actions when needed.

## Startup and remote configuration

Start initialization before the remote configuration request completes.
Register placements after IDs resolve. Registration can occur while consent is pending.
Do not use a `canRequestAds` snapshot to skip registration or the first wait.

```dart
Future<void> registerRemotePlacements(Future<Iterable<AdPlacement>> resolvedPlacements) async {
  AdmobKit.registerPlacements(await resolvedPlacements);
}
```

If the chosen splash placement itself depends on remote configuration, resolve that
placement before waiting for it. Do not wait for an old or guessed placement in parallel.

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

Set `isSplash: true` on a splash interstitial or app-open placement.
Set `loadOnce: true` when background replacement is not needed after consumption.
`waitFor` includes eligibility resolution. Its false result is a normal unavailable-ad outcome.
It does not guarantee that `show` will display an ad; presentation can be blocked later.
Initialization errors and remote configuration errors need app-owned error handling.
An ad timeout does not limit how long consent or SDK initialization can take.

## Rewards

Register the selected reward placement before the feature becomes reachable.
Both reward formats use the same earned-reward callback.

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

Pass a `RewardedPlacement` or `RewardedInterstitialPlacement` here.
Do not unlock from `onDismissed`; it also runs after a skipped or unsuccessful presentation.
For a button that needs a ready-state decision, use `await waitFor(placement)` before `show`.
Handle a false result with normal unavailable-ad UI. Do not add a custom retry loop.

## Native and banner content

Widgets load their own ads and dispose their own instances. Do not wait for an inline ad
before mounting its widget. A widget can load on demand after a `loadOnce` ad was consumed.

```dart
Widget nativeFeedItem() => const AdNativeView(placement: AppAds.native);

Widget stickyBanner() => const SafeArea(child: AdBannerView(placement: AppAds.banner));
```

Give native ads bounded width of at least 320 logical pixels and content-sized inline height.
Give banners bounded width; their height comes from adaptive sizing.
For a banner in a scrolling feed, declare a separate placement:

```dart
const feedBanner = BannerPlacement(
  id: 'feed_banner',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.inlineAdaptive(maxHeight: 160),
);

Widget inlineBanner() => const AdBannerView(placement: feedBanner);
```

Only an explicit early banner wait needs the known future host layout.
Use the actual available width and device orientation, not a universal hardcoded width.

```dart
Future<bool> prepareBanner(int logicalWidth, BannerOrientation orientation) => AdmobKit.waitFor(
  AppAds.banner,
  bannerLayout: BannerLayout(width: logicalWidth, orientation: orientation),
);
```

## Tabs and retained pages

For `PageView`, `TabBarView`, or a custom retained-page container, pass selection state.
`active` cannot override an inactive `Visibility` or `TickerMode` ancestor.

```dart
Widget nativePage(int pageIndex, int selectedIndex) => AdNativeView(
  placement: AppAds.native,
  active: pageIndex == selectedIndex,
);
```

The widgets use Flutter's visibility signals, including `IndexedStack` visibility.
An ordinary offscreen list item is not necessarily inactive. Mounting does not measure viewport visibility.
For fullscreen natives, always supply the actual selected-page activity.
The library must not infer fullscreen ownership from a mounted offscreen page.

## First-run screens and shared placements

Register first-run placements only when onboarding is reachable.
The app must also avoid mounting those screens for returning users.
Registration alone does not prevent an inline host from requesting an ad.

Several native widgets can share a placement if their configuration is identical.
They receive distinct instances. If two slots are normally visible together, a capacity of two can prepare both.
Do not reuse an ID for different native templates or banner sizing.

```dart
void registerReachableAds({required bool firstLaunch, required NativePlacement onboarding}) {
  AdmobKit.registerPlacements(
    [AppAds.transition, AppAds.native, AppAds.banner, if (firstLaunch) onboarding],
    placementCapacities: {AppAds.native.id: 2},
  );
}
```

## Fullscreen native ads

Use a native placement with a fullscreen template and `AdNativeView`, not `show`.
Keep the app's dismiss control outside SDK ad assets.

```dart
Widget fullscreenNativeRoute(NativePlacement placement, VoidCallback onContinue) => Scaffold(
  body: SafeArea(child: AdNativeView(placement: placement)),
  bottomNavigationBar: SafeArea(
    child: TextButton(onPressed: onContinue, child: const Text('Continue')),
  ),
);
```

The placement must use a fullscreen template. The body must have bounded width and height of at least 320.
Actual copy and media may require more room. There is no package close button.
Only loaded, measured, active fullscreen content owns presentation. A loading placeholder does not.
Read the [native production limit](native-ads.md#production-limit) before release.

## Paywall exit

Use one trigger for the close button and intercepted system back action.
Pass purchase completion to the guard. The app controls the final navigation.

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

## App-open ads on resume

Register an `AppOpenPlacement`. Request it from the app's lifecycle handler only when app policy permits.
Exclude cold-start duplicates, permission interruptions, short background transitions, and app-owned dialogs or paywalls.
The app owns dwell time and cooldown. The library rejects conflicting ad presentation.

```dart
void showResumeAd(AppOpenPlacement placement, {required bool appPolicyAllowsResumeAd}) {
  if (!appPolicyAllowsResumeAd) return;
  AdmobKit.show(placement);
}
```

`isShowingAd` can support a status UI. It does not detect arbitrary app overlays.
Use `onDisplayed` to start a display-based cooldown, not the time when `show` was called.

## Premium access

Supply one callback that reads current entitlement. Do not repeat the premium check before each ad call.
Rebuild ad hosts when entitlement changes; the callback is not a subscription.

```dart
AdmobKitConfig premiumConfig(bool Function() hasAdFreeAccess) => AdmobKitConfig(isPremium: hasAdFreeAccess);
```

Premium users skip ad requests and fullscreen presentation. Rebuilt inline hosts collapse.
For a purchase inside a paywall, also update `isPurchased` so the exit guard can immediately bypass its ad.

## Privacy settings

Check the public requirement API after initialization has started.
Show the settings control only when required. A query error is not a not-required result.
Keep a stable future for the settings UI and permit a retry after an error.

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

The form result does not mean consent was granted. Loading eligibility is resolved by the library afterward.
Do not request another form while a fullscreen ad is visible.
See [Setup](setup.md) for AdMob privacy-message configuration and test geography.

## Analytics and diagnostics

Implement the public tracker contracts and pass them to configuration.
Tracker callbacks must handle service errors themselves.

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

## Native styling

Choose colors and CTA radius through `NativeAdStyle`. Await live updates.
Read [Native ads](native-ads.md#colors-and-cta-radius) for inheritance and resets.
