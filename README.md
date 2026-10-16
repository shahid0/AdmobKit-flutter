# AdmobKit for Flutter

AdmobKit manages Google AdMob ads in Flutter apps on Android and iOS.
The engine automates user consent, loading queues, warm caching, network timeouts, retries, and presentation safety.

Your app declares placements and triggers display at natural navigation points.
Use `show` for fullscreen ads.
Use `waitFor` only when a user flow must pause for an ad decision.
Mount `AdBannerView` and `AdNativeView` directly in your widget tree.
Do not build custom ad-loading controllers or retry loops.

## What the Engine Automates

- **Zero-latency presentation**: Preloads ads into a warm memory cache for 0ms display.
- **Privacy compliance**: Gathers consent through Google UMP and requests iOS ATT permission.
- **Automatic replenishment**: Preloads replacement ads in the background after each display.
- **Network resilience**: Adjusts timeouts dynamically for cellular data and high-latency networks.
- **Intelligent retries**: Schedules exponential backoff with randomized jitter on network errors.
- **Stale ad eviction**: Disposes ads automatically when their time-to-live expires.
- **Presentation safety**: Locks fullscreen presentation to prevent multiple overlapping ads.
- **Non-blocking leasing**: Mounts inline ads cleanly without causing layout shifts.

## What Your App Controls

- Declare placement identifiers and format specifications.
- Choose when to trigger fullscreen display during navigation.
- Supply an entitlement callback to suppress ads for premium users.

## Setup

Requires Dart 3.11.5 or later and Flutter 3.41.0 or later.

```sh
flutter pub add admob_kit_flutter
```

Complete platform configuration in [Platform setup](docs/setup.md) before you run the app.
Use test ad unit identifiers during development.

Native templates have a known text-truncation limit.
Read the [native ad guide](docs/native-ads.md#production-limit) before production release.

## Complete Example

This example uses only the supported package import.
You can register placements while initialization is pending.
The engine resolves consent and SDK readiness before it requests ads.

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

Put your normal button action inside `onDismissed`.
The engine executes `onDismissed` even when an ad cannot show.

## Decision Matrix

### Ad Format Selection

| Ad Format | Placement Class | Primary Use Case |
| :--- | :--- | :--- |
| **Interstitial** | `InterstitialPlacement` | Natural screen transitions, completed actions, step changes |
| **Rewarded** | `RewardedPlacement` | Optional user rewards, extra lives, currency unlock |
| **Rewarded Interstitial** | `RewardedInterstitialPlacement` | Pre-announced rewards without opt-in prompts |
| **App Open** | `AppOpenPlacement` | Cold app launch and return from background |
| **Adaptive Banner** | `BannerPlacement` | Anchored screen headers, footers, or inline feed breaks |
| **Native Template** | `NativePlacement` | Content feeds matching app design and typography |

### Method Selection

- **Use `AdmobKit.show()` for instant fullscreen presentation**:
  The engine shows the cached ad immediately.
  If no ad is ready, the engine runs `onDismissed` at once.
  Users experience 0ms wait time.

- **Use `AdmobKit.waitFor()` only when a flow must pause**:
  Use `waitFor` for cold-start splash screens or reward buttons that show a loading indicator.
  Handle a `false` result by showing normal app content.

- **Mount `AdBannerView` or `AdNativeView` directly**:
  Widgets manage their own loading and layout measurement.
  Never await an inline ad before mounting.

### Timeout Profile Selection

- **`AdTimeoutConfig.standard`**:
  Default profile for global mobile audiences.
  Allocates 30s Wi-Fi / 50s cellular for fullscreen ads.

- **`AdTimeoutConfig.emergingMarkets`**:
  Profile for regions with high latency or constrained 2G/3G connectivity (e.g. Ethiopia, Pakistan).
  Allocates up to 75s on cellular data to prevent premature download aborts.

```dart
AdmobKitConfig emergingMarketsConfig() => const AdmobKitConfig(
  timeouts: AdTimeoutConfig.emergingMarkets,
);
```

## Rules for Developers and AI Agents

Follow these architectural rules when integrating this package:

1. **Do not create custom loading controllers or retry loops**:
   The engine manages background queues, preloading, and backoff retries automatically.

2. **Never await an ad before mounting an inline widget**:
   Mount `AdBannerView` or `AdNativeView` directly.
   The host widget displays an internal placeholder until the ad is ready.

3. **Place post-ad navigation in `onDismissed`**:
   The engine always calls `onDismissed`, even when an ad is skipped, unavailable, or denied.

4. **Unlock rewards only in `onRewardGranted`**:
   Never grant user rewards inside `onDismissed`.
   `onDismissed` also runs when an ad fails or user cancels early.

5. **Supply premium status through `isPremium`**:
   Pass a synchronous boolean function to `AdmobKitConfig(isPremium: () => false)`.
   When entitlement changes, rebuild your widget tree.

## Guides

| Guide | Description |
| :--- | :--- |
| [Use cases](docs/recipes.md) | Recipes for transitions, rewards, banners, feeds, tabs, and splash |
| [Public API](docs/api.md) | Methods, parameters, return types, error contracts, and defaults |
| [Native ads](docs/native-ads.md) | Templates, styling parameters, layout bounds, and truncation limits |
| [Platform setup](docs/setup.md) | Android manifest, iOS Info.plist, UMP consent, and test devices |
| [Troubleshooting](docs/troubleshooting.md) | Common errors, missing ads, Ad Inspector, and network diagnostics |

## AI Coding Agents

Install the integration skill:

```sh
npx skills add shahid0/AdmobKit-flutter
```

The skill selects the correct use-case recipe and explains which public API to call.

## License

[MIT](LICENSE). Template credits are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
