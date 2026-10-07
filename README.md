# AdmobKit for Flutter

AdmobKit manages Google AdMob ads in Flutter apps on Android and iOS.
It handles consent, loading, retries, cached ads, and exclusive fullscreen presentation.

Your app declares placements and decides where ads belong.
Use `show` for SDK fullscreen ads. Use `waitFor` when a flow must wait for an ad decision.
Use `AdBannerView` and `AdNativeView` for ads in a layout.
Do not create an extra ad-loading controller.

## Setup

Requires Dart 3.11.5 or later and Flutter 3.41.0 or later.

```sh
flutter pub add admob_kit_flutter
```

Complete [Android and iOS setup](docs/setup.md) before running the app.
Use test ad unit IDs during development.

Native templates have a known text-truncation limitation.
Read the [native ad guide](docs/native-ads.md#production-limit) before production use.

## Complete example

This example uses only the supported package import.
Registration can occur while initialization is pending.
The library waits for consent and SDK readiness before requesting ads.

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

The same example is in [example/lib/minimal.dart](example/lib/minimal.dart).
Run it from the example directory:

```sh
flutter run -t lib/minimal.dart
```

The normal button action belongs in `onDismissed`.
That callback also runs when an ad cannot be shown.

## Choose a guide

| Need | Guide |
| --- | --- |
| Startup, splash, rewards, paywall exit, tabs, or remote configuration | [Use cases](docs/recipes.md) |
| Method arguments, return values, callbacks, defaults, or errors | [Public API](docs/api.md) |
| Native templates, layout bounds, colors, or CTA radius | [Native ads](docs/native-ads.md) |
| App IDs, consent, ATT, or test devices | [Platform setup](docs/setup.md) |
| Missing ads, state checks, or Ad Inspector | [Troubleshooting](docs/troubleshooting.md) |

These guides define the supported app integration.
You do not need to inspect the pool, queue, platform bridge, or SDK driver.

## AI coding agents

Install the [integration skill](skills/flutter-ads/SKILL.md):

```sh
npx skills add shahid0/AdmobKit-flutter
```

The skill selects a use-case guide and explains which public API to use.
Its references contain the same instructions as the public guides.

## Example gallery

The larger example app contains the template gallery and diagnostic screens.
Run `flutter run` from `example` to open it.
Use the minimal example as the starting point for app integration.

## License

[MIT](LICENSE). Template credits are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
