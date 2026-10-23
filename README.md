# AdmobKit for Flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)

Google AdMob for Flutter on Android and iOS, with one small API.
AdmobKit handles consent, preloading, queueing, retries, freshness, offline handling, and fullscreen ownership. Your app declares placements, shows ads at transitions, and mounts ad widgets.

**Full documentation:** [Recipes](GUIDErecipes.md) · [Best practices](GUIDEbest-practices.md) · [Design decisions](GUIDEdesign-decisions.md) · [API reference](GUIDEapi.md) · [Native ads](GUIDEnative-ads.md) · [Platform setup](GUIDEsetup.md) · [Troubleshooting](GUIDEtroubleshooting.md) · [Migrating from 0.0.2](GUIDEmigration.md)

## Contents

- [Features](#features)
- [Install and set up](#install-and-set-up)
- [Minimal app](#minimal-app)
- [Usage](#usage)
- [Configuration](#configuration)
- [How AdmobKit behaves](#how-admobkit-behaves)
- [Troubleshooting](#troubleshooting)
- [Documentation](#documentation)

## Features

- **Consent first**: Google UMP and Apple ATT run before any ad is requested.
- **Preloading by registration**: fullscreen, native, and fixed banner ads load before their screens open, in priority order.
- **Deterministic waits**: `waitFor` and `waitForAll` settle when ads are ready or cannot come, so splash screens and funnels never hang.
- **Show that never blocks**: `show` presents a cached ad or continues at once.
- **Banners that fit**: anchored and inline adaptive banners, fixed sizes, collapsible banners, and no layout jump on rotation.
- **19 native templates** with live styling, measured heights, and fullscreen pages.
- **Lists and tabs that just work**: each ad goes to one visible widget and stays with it.
- **Offline-aware**: the queue pauses offline and resumes when the network returns.
- **Analytics and diagnostics** hooks for revenue and network health.

## Install and set up

```sh
flutter pub add admob_kit_flutter
```

**Android**: add your AdMob app ID to `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
    <meta-data
        android:name="com.google.android.gms.ads.APPLICATION_ID"
        android:value="ca-app-pub-3940256099942544~3347511713" />
</application>
```

**iOS**: add your app ID and the tracking description to `ios/Runner/Info.plist`, plus Google's `SKAdNetworkItems`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<key>NSUserTrackingUsageDescription</key>
<string>This identifier helps us deliver personalized advertisements to you.</string>
```

The values above are Google's test app IDs; replace them with yours before release. Rebuild the app after changing these files. Consent messages and test devices are covered in [Platform setup](GUIDEsetup.md).

## Minimal app

```dart
import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class AppAds {
  static const transition = InterstitialPlacement(
    id: 'transition',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );
  static const native = NativePlacement(
    id: 'feed',
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    template: NativeAdTemplate.feedMediaFirst,
  );
  static const banner = BannerPlacement(
    id: 'footer',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = AdmobKit.initialize();
  AdmobKit.registerPlacements([AppAds.transition, AppAds.native, AppAds.banner]);
  runApp(const ExampleApp());
  try {
    await boot;
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: ExampleScreen());
}

class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AdmobKit example')),
    body: ListView(
      children: [
        const Text('App content'),
        LayoutBuilder(
          builder: (context, bounds) => bounds.maxWidth >= AppAds.native.template.minWidth
              ? const AdNativeView(placement: AppAds.native)
              : const SizedBox.shrink(),
        ),
        TextButton(
          onPressed: () => AdmobKit.show(
            AppAds.transition,
            onDismissed: () {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action completed')));
            },
          ),
          child: const Text('Continue'),
        ),
      ],
    ),
    bottomNavigationBar: const SafeArea(child: AdBannerView(placement: AppAds.banner)),
  );
}
```

`onDismissed` always runs, whether or not an ad showed, so the normal action lives there.

## Usage

The snippets below use `AppAds` from the minimal app.

### Initialize and register

Call `initialize` once in `main`, then register placements for the screens this user can reach. Registration starts preloading fullscreen, native, and fixed banner ads.

```dart
void registerForUser({required bool firstLaunch, required NativePlacement onboarding}) {
  AdmobKit.registerPlacements([AppAds.transition, AppAds.native, AppAds.banner, if (firstLaunch) onboarding]);
}
```

### Transitions

`show` presents a cached ad or calls `onDismissed` at once; it never waits for a download. Put navigation in `onDismissed`.

```dart
void continueWithAd(VoidCallback openNextScreen) {
  AdmobKit.show(AppAds.transition, onDismissed: openNextScreen);
}
```

Your app decides how often transitions show an ad. Avoid two fullscreen ads back to back.

### Rewarded ads

Grant rewards only in `onRewardGranted`; `onDismissed` also runs for skipped or missing ads.

```dart
const rewardedCoins = RewardedPlacement(
  id: 'coins',
  androidId: AdMobTestIds.rewardedAndroid,
  iosId: AdMobTestIds.rewardedIos,
);

void watchForCoins(VoidCallback grantCoins) {
  AdmobKit.show(rewardedCoins, onRewardGranted: (amount, type) => grantCoins());
}
```

### Splash screen

Mark cold-start placements with `isSplash: true` and wait for the ad together with your startup work.

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

`waitFor` needs no timeout: it settles when the ad is ready or cannot come, and returns `false` at once while offline. Pass `timeout` only when you have a real time budget, such as the length of a task the user is doing.

### Funnels

`waitForAll` prepares a whole step, for example every onboarding ad while the splash screen is up. Ads load in list order and stay buffered for the next screen.

```dart
Future<void> prepareOnboarding(VoidCallback openOnboarding) async {
  await AdmobKit.waitForAll([AppAds.native, AppAds.transition]);
  openOnboarding();
}
```

### Banners

Mount `AdBannerView`. It loads, sizes, and refreshes itself.

| Sizing | Use it for | Loads |
| :--- | :--- | :--- |
| `BannerSizing.anchoredAdaptive()` (default) | Sticky top or bottom bars | When it lays out |
| `BannerSizing.inlineAdaptive(maxHeight: 160)` | Banners in scrolling content | When it lays out |
| `standard()`, `mrec()`, `large()`, `leaderboard()`, `fixed(...)` | Banners that must be ready before the screen opens | At registration |

```dart
const rectangleBanner = BannerPlacement(
  id: 'rectangle',
  androidId: AdMobTestIds.bannerAndroid,
  iosId: AdMobTestIds.bannerIos,
  sizing: BannerSizing.mrec(),
);

Widget stickyBanner() => const SafeArea(child: AdBannerView(placement: AppAds.banner));
Widget rectangle() => const AdBannerView(placement: rectangleBanner);
```

Inline and fixed banners reserve their height and show a "Loading ad" shimmer while loading. For a collapsible banner, use `BannerPlacement.collapsible(...)`.

### Native ads

Pick one of 19 templates and mount `AdNativeView` with at least 320 logical pixels of width. Inline templates size themselves; fullscreen templates fill a bounded height.

```dart
const cardNative = NativePlacement(
  id: 'card',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  template: NativeAdTemplate.cardContentTop,
  style: NativeAdStyle(callToActionBackground: 0xff2563eb, callToActionText: 0xffffffff),
);

Widget cardAd() => const AdNativeView(placement: cardNative);

Future<void> useDarkAds() => AdmobKit.setNativeStyle(const NativeAdStyle(background: 0xff101010, headline: 0xfff5f5f5));
```

Templates, layout bounds, and styling are covered in [Native ads](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/native-ads.md).

### Tabs, pages, and lists

Mount ad widgets directly in tabs, `PageView` pages, `IndexedStack` children, and list items. No extra parameters are needed: a widget requests when visible, a returning ad goes to a visible widget, and a delivered ad stays with its widget across routes, tab switches, and scrolling. Keep keys and placements stable.

### Paywall exit

```dart
Widget guardedPaywall(VoidCallback onClose, {bool purchased = false}) => AdPaywallGuard(
  placement: AppAds.transition,
  isPurchased: purchased,
  onDismiss: onClose,
  builder: (context, close) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: close, icon: const Icon(Icons.close))),
    body: const Text('Subscription options'),
  ),
);
```

The close button and the Android back button share one exit, which shows the ad once for users who leave without buying.

### App-open ads

Register an `AppOpenPlacement` and call `AdmobKit.show(placement)` from your lifecycle code when your app decides a resume should show one. An app-open ad never shows over another fullscreen ad.

### Premium users

```dart
AdmobKitConfig premiumConfig(bool Function() hasAdFreeAccess) => AdmobKitConfig(isPremium: hasAdFreeAccess);
```

Premium users get no requests and no ads; rebuild your widgets when entitlement changes.

### Privacy settings

Show a privacy entry when `AdmobKit.isPrivacyOptionsRequired()` returns `true`, and open it with `AdmobKit.showPrivacyOptionsForm()`. A full widget is in the [recipes](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/recipes.md#privacy-settings).

## Configuration

Pass `AdmobKitConfig` to `initialize`:

```dart
Future<void> startAds() => AdmobKit.initialize(
  config: const AdmobKitConfig(
    timeouts: AdTimeoutConfig.emergingMarkets,
    testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
  ),
);
```

| Field | Default | Purpose |
| :--- | :--- | :--- |
| `requestConsent` | `true` | Run Google UMP and Apple ATT before requesting ads |
| `isPremium` | `null` | Synchronous entitlement check that suppresses all ads |
| `placements` | `null` | Placements registered during initialization |
| `placementCapacities` | `null` | Buffered ads per placement id (default 1) |
| `initialConcurrency` / `subsequentConcurrency` | `1` / `1` | Parallel downloads at startup and afterwards |
| `timeouts` | `AdTimeoutConfig.standard` | Download windows: `standard`, `emergingMarkets`, `relaxed`, `aggressive` |
| `adTtl` | 50 minutes | Age after which an unshown ad is replaced |
| `nativeStyle` | `NativeAdStyle()` | App-wide native style |
| `analytics` / `diagnostics` | `null` | Revenue, lifecycle, and network health callbacks |
| `logLevel` | verbose in debug, silent in release | Console logging |
| `consentTestConfig`, `testDeviceIds` | `null` | Consent and ad testing |

Every option is described in the [API reference](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/api.md#configuration).

## How AdmobKit behaves

- `show` never waits for a download, and `onDismissed` always runs exactly once.
- `waitFor` and `waitForAll` are deterministic; `timeout` is an optional time budget.
- Only one fullscreen ad owns the screen at a time.
- The ad the user is waiting for loads first; downloads run one at a time by default to keep slow networks responsive.
- Recurring placements keep one spare ready; `loadOnce` placements load once.
- Ads that were never shown are replaced after `adTtl`; shown ads are never discarded.
- Offline, waits return `false` at once and loads resume when the network returns.
- The package decides only what correctness or AdMob policy requires; product choices stay with your app.

The reasoning behind each of these is in [Design decisions](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/design-decisions.md).

## Troubleshooting

| Error code | Meaning | What to do |
| :--- | :--- | :--- |
| `0` | Internal error | Check device logs and connectivity |
| `1` | Invalid request | Check the unit ID matches the placement type, and the app ID in the manifest and `Info.plist` |
| `2` | Network error | Check the network; use `AdTimeoutConfig.emergingMarkets` on slow networks |
| `3` | No fill | Expected for new accounts; AdmobKit retries with backoff |

Diagnose with `AdmobKit.initializationState`, `AdmobKit.getState(placement)`, `logLevel: AdLogLevel.verbose`, and `AdmobKit.openAdInspector()`. More in [Troubleshooting](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/troubleshooting.md).

## Documentation

| Guide | What it covers |
| :--- | :--- |
| [Recipes](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/recipes.md) | Complete code for every flow: transitions, rewards, splash, funnels, banners, natives, tabs, paywalls, app open, remote config, premium, privacy, telemetry |
| [Best practices](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/best-practices.md) | The rules for getting an impression from every request |
| [Design decisions](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/design-decisions.md) | Why AdmobKit works the way it does |
| [API reference](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/api.md) | Every public method, widget, placement, and setting |
| [Native ads](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/native-ads.md) | Templates, layout bounds, styling, and policy limits |
| [Platform setup](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/setup.md) | App IDs, consent messages, ATT, and test devices |
| [Troubleshooting](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/troubleshooting.md) | Error codes and common problems |
| [Migrating from 0.0.2](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/migration.md) | Changes needed to upgrade to 0.1.0 |

## AI coding agents

AdmobKit ships an agent skill with the API, the recipes, and the reasoning behind them:

```sh
npx skills add shahid0/AdmobKit-flutter
```

## Requirements

- Flutter 3.41.0 or later, Dart 3.11.5 or later.
- Android API 24 or later; iOS 13.0 or later.
- `google_mobile_ads` 9.1.0 or a later 9.x release, installed with this package.

## License

[MIT](https://github.com/shahid0/AdmobKit-flutter/blob/main/LICENSE)
