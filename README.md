# AdmobKit for Flutter

AdmobKit is a production-grade Google AdMob engine for Flutter on Android and iOS.
The engine preloads ads into a warm memory cache to provide 0ms instant display.
It prevents banner layout shifts, automates Google UMP consent, and handles network retries.

Traditional AdMob integrations force apps to manage complex ad lifecycles.
Apps suffer from slow cold-start loads, jumping banner heights, and thread pauses.
AdmobKit automates these operations in the background.
Your application only declares placements and triggers display at natural transition points.

## Comparison: Raw GMA SDK vs. AdmobKit

| Capability | Raw Google Mobile Ads SDK | AdmobKit |
| :--- | :--- | :--- |
| **Presentation Latency** | 2 to 5 second network download wait | **0ms instant display** from eager memory pool |
| **Banner Layout** | Jumps and causes Cumulative Layout Shift (CLS) | **Zero layout shift** via reserved adaptive heights |
| **Consent Management** | Manual Google UMP boilerplate and state loops | **Automated UMP and Apple ATT** synchronization |
| **Network Resilience** | Fails silently on network errors | **Exponential backoff with randomized jitter** |
| **Slow Connections** | Requests drop on high-latency networks | **`emergingMarkets` timeout profile** (up to 75s) |
| **Hidden Tabs and Pages** | Hidden pages request ads users never see, and returning reloads them | **Deferred first request, retained ads**, with no parameters to wire |
| **Presentation Safety** | Overlapping fullscreen ads crash or hide content | **Hardware presentation mutex** prevents collisions |

## System Responsibilities

### What the Engine Automates

- **Zero-latency display**: Preloads ads into a warm memory cache before user navigation.
- **Privacy compliance**: Gathers consent through Google UMP and requests iOS ATT permission.
- **Automatic replenishment**: Preloads replacement ads in the background after each display.
- **Network resilience**: Adjusts timeouts dynamically for cellular data and slow connections.
- **Intelligent retries**: Schedules exponential backoff with randomized jitter on network errors.
- **Stale ad eviction**: Disposes ads automatically when their time-to-live expires.
- **Presentation safety**: Locks fullscreen presentation to prevent multiple overlapping ads.
- **Non-blocking leasing**: Mounts inline ads cleanly without causing layout shifts.

### What Your App Controls

- Declare placement identifiers and format specifications.
- Choose when to trigger fullscreen display during user navigation.
- Supply an entitlement callback to suppress ads for premium users.

## Quickstart

### 1. Add the Dependency

Add the package to your Flutter project:

```sh
flutter pub add admob_kit_flutter
```

Configure your AdMob App ID in your Android Manifest and iOS `Info.plist`.
Read the [Platform setup guide](docs/setup.md) for platform instructions.

### 2. Complete Minimal App

The minimal app demonstrates initialization, placement registration, and display:

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

## Production Recipes

### 1. Screen Transitions (0ms Display)

Show an interstitial ad during natural transitions, such as completing a task.
Put your normal navigation logic in `onDismissed`.
The engine calls `onDismissed` immediately if no ad is ready.

```dart
void triggerScreenTransition(BuildContext context, VoidCallback navigate) {
  AdmobKit.show(
    AppAds.transition,
    onDismissed: navigate,
  );
}
```

### 2. Cold-Start Launch and Splash Screens

Use `AdmobKit.waitFor()` only when a user flow must pause for an ad decision.
`waitFor` handles pending consent and SDK initialization automatically.

```dart
Future<void> handleAppColdStart(VoidCallback launchHome) async {
  final ready = await AdmobKit.waitFor(
    AppAds.transition,
    timeout: const Duration(seconds: 4),
  );
  if (ready) {
    AdmobKit.show(AppAds.transition, onDismissed: launchHome);
  } else {
    launchHome();
  }
}
```

### 3. Rewarded User Actions

Grant rewards only inside `onRewardGranted`.
Never grant rewards inside `onDismissed`.
`onDismissed` also runs when an ad is skipped or unavailable.

```dart
const rewardedPlacement = RewardedPlacement(
  id: 'rewarded_coins',
  androidId: AdMobTestIds.rewardedAndroid,
  iosId: AdMobTestIds.rewardedIos,
);

void requestReward(VoidCallback onGranted) {
  AdmobKit.show(
    rewardedPlacement,
    onRewardGranted: (amount, type) => onGranted(),
    onDismissed: () {
      debugPrint('Ad dismissed or unavailable.');
    },
  );
}
```

### 4. Anchored Bottom Banners (Zero Layout Shift)

Mount `AdBannerView` directly inside your `Scaffold.bottomNavigationBar`.
The banner reserves its maximum adaptive height automatically.

```dart
Widget buildBottomBanner() {
  return const SafeArea(
    child: AdBannerView(placement: AppAds.banner),
  );
}
```

### 5. In-Feed Native Ads

Mount `AdNativeView` directly inside your `ListView` or `CustomScrollView`.
Make certain the container has at least 320 logical pixels of bounded width.

```dart
Widget buildFeedNativeAd() {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < AppAds.native.template.minWidth) {
        return const SizedBox.shrink();
      }
      return const AdNativeView(placement: AppAds.native);
    },
  );
}
```

### 6. Paywall Dismissal Guard

Use `AdPaywallGuard` to display an ad when a non-paying user closes a paywall.
`AdPaywallGuard` intercepts both the UI close button and the hardware Android back button.

```dart
Widget buildPaywallScreen(VoidCallback dismissPaywall) {
  return AdPaywallGuard(
    placement: AppAds.transition,
    onDismiss: dismissPaywall,
    child: Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: const Center(child: Text('Paywall Content')),
    ),
  );
}
```

## Emerging Markets and Low-Bandwidth Networks

In countries like Ethiopia, Pakistan, or India, cellular connections often have high latency.
Standard network timeouts can abort ad downloads prematurely.

AdmobKit provides an `emergingMarkets` timeout profile.
This profile allocates up to 75 seconds on cellular data to maximize fill rate:

```dart
AdmobKitConfig emergingMarketsConfig() => const AdmobKitConfig(
  timeouts: AdTimeoutConfig.emergingMarkets,
);
```

## Decision Framework

### Ad Format Selection

| Ad Format | Placement Class | Primary Use Case | User Experience Impact |
| :--- | :--- | :--- | :--- |
| **Interstitial** | `InterstitialPlacement` | Natural screen transitions, completed steps | Fullscreen overlay; dismissed by user |
| **Rewarded** | `RewardedPlacement` | Optional user rewards, currency, unlocks | Opt-in fullscreen; rewards on completion |
| **Rewarded Interstitial** | `RewardedInterstitialPlacement` | Pre-announced rewards without opt-in prompts | Fullscreen overlay with countdown timer |
| **App Open** | `AppOpenPlacement` | Cold app launch and return from background | Fullscreen overlay on app foregrounding |
| **Adaptive Banner** | `BannerPlacement` | Anchored screen headers, footers, feed breaks | Anchored inline bar; zero layout shift |
| **Native Template** | `NativePlacement` | Content feeds matching app design and theme | Custom styled inline widget |

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

## Diagnostics and Ad Inspector

Open the native Google Ad Inspector to verify mediation adapters and ad units on device:

```dart
void inspectAdIntegration() {
  AdmobKit.openAdInspector((error) {
    if (error != null) {
      debugPrint('Ad Inspector error: $error');
    }
  });
}
```

Read [Troubleshooting](docs/troubleshooting.md) for standard error codes (`0`, `1`, `2`, `3`) and layout solutions.

## Documentation Guides

| Guide | Description |
| :--- | :--- |
| [Best practices](docs/best-practices.md) | What to choose and why: registration, priorities, banners, natives, hidden pages, metrics |
| [Use cases and recipes](docs/recipes.md) | Complete recipes for transitions, rewards, banners, feeds, tabs, and splash |
| [Public API surface](docs/api.md) | Methods, parameters, return types, error contracts, and engine defaults |
| [Native ads catalog](docs/native-ads.md) | Templates, styling parameters, layout bounds, and truncation limits |
| [Platform setup](docs/setup.md) | Android manifest, iOS Info.plist, UMP consent, ATT, and test devices |
| [Troubleshooting](docs/troubleshooting.md) | Common errors, missing ads, Ad Inspector, and network diagnostics |

## AI Coding Agents

Install the integration skill:

```sh
npx skills add shahid0/AdmobKit-flutter
```

The skill selects the correct use-case recipe and explains which public API to call.

## License

[MIT](LICENSE). Template credits are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
