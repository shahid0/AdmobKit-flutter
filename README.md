# AdmobKit for Flutter

[![pub package](https://img.shields.io/pub/v/admob_kit_flutter.svg)](https://pub.dev/packages/admob_kit_flutter)

Google AdMob for Flutter on Android and iOS, with one small API.
AdmobKit handles consent, preloading, queueing, retries, freshness, and fullscreen ownership, so your app only declares placements, shows ads at transitions, and mounts ad widgets.

## Features

- **Consent first**: Google UMP and Apple ATT run before any ad is requested.
- **Preloading by registration**: fullscreen, native, and fixed banner ads load before their screens open, in priority order.
- **Deterministic waits**: `waitFor` and `waitForAll` settle when ads are ready or cannot come, so splash screens and funnels never hang.
- **Show that never blocks**: `show` presents a cached ad or continues at once.
- **Banners that fit**: anchored and inline adaptive banners, fixed sizes, collapsible banners, no blank bands, and no layout jump on rotation.
- **19 native templates** with live styling, measured heights, and a fullscreen family.
- **Lists and tabs that just work**: each ad goes to one visible widget and stays with it.
- **Offline-aware**: the queue pauses offline and resumes when the network returns.
- **Analytics and diagnostics** hooks for revenue and network health.

## Install

```sh
flutter pub add admob_kit_flutter
```

Add your AdMob app ID to `AndroidManifest.xml` and `Info.plist` as described in [Platform setup](doc/setup.md), then rebuild the app.

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

## How it works

1. **Initialize once** in `main`. `initialize` collects consent and starts the SDK in the background.
2. **Register placements** for the screens this user can reach. Registration starts preloading.
3. **Show fullscreen ads** with `AdmobKit.show` at natural transitions. Use `waitFor` when a flow needs one specific ad, and `waitForAll` to prepare a whole funnel step.
4. **Mount** `AdBannerView` and `AdNativeView` where ads appear. They request, size, and keep their own ads.

```dart
Future<void> runSplash(BuildContext context, Future<void> appReady, VoidCallback onContinue) async {
  await Future.wait([appReady, AdmobKit.waitFor(AppAds.transition)]);
  if (!context.mounted) return;
  AdmobKit.show(AppAds.transition, onDismissed: onContinue);
}
```

`waitFor` needs no timeout: it settles on its own. Pass `timeout` only when you have a real time budget.

## Documentation

| Guide | What it covers |
| :--- | :--- |
| [Platform setup](doc/setup.md) | App IDs, consent messages, ATT, test devices |
| [Recipes](doc/recipes.md) | Transitions, rewards, splash, funnels, banners, natives, tabs, paywalls, app open, premium, privacy |
| [Best practices](doc/best-practices.md) | The rules for getting impressions from every request |
| [Design decisions](doc/design-decisions.md) | Why AdmobKit works the way it does |
| [API reference](doc/api.md) | Every public method, widget, placement, and setting |
| [Native ads](doc/native-ads.md) | Templates, layout bounds, styling, policy limits |
| [Troubleshooting](doc/troubleshooting.md) | Error codes and common problems |
| [Migrating from 0.0.2](doc/migration.md) | Changes needed to upgrade to 0.1.0 |

## AI coding agents

AdmobKit ships an agent skill that knows the API, the recipes, and the reasoning behind them:

```sh
npx skills add shahid0/AdmobKit-flutter
```

## Requirements

- Flutter 3.41.0 or later, Dart 3.11.5 or later.
- Android API 24 or later; iOS 13.0 or later.
- `google_mobile_ads` 9.1.0 or a later 9.x release, installed with this package.

## License

[MIT](LICENSE)
