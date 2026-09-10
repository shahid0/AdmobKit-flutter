# flutter_ads

Opinionated, high-performance mobile ad orchestration engine for Flutter apps with Google Mobile Ads (AdMob) and User Messaging Platform (UMP).

Designed with a **0ms non-blocking display contract**, **deterministic settlement**, and **single-thread radio optimization** for slow networks.

---

## Key Features

- **0ms Non-Blocking Show**: `FlutterAds.show()` presents cached ads instantly or invokes `onDismissed` with 0ms delay if unready or offline. Never stalls navigation.
- **Deterministic Settlement (`waitFor`)**: Compose splash ad preloading cleanly with Firebase Remote Config and Authentication session restoration using `Future.wait`. Zero blind timers (`Timer()`).
- **Two-Stage Initialization**: Boot UMP consent and GMA SDK immediately at app launch (`main()`), then prime placements via `registerPlacements()` as soon as remote configuration resolves.
- **Immediate-Display Priority**: Dedicates 100% of network throughput to the active screen's visible ad before initiating downstream background preloads.
- **Template-Bound Native Sizing**: Concrete dimensions on native templates (`template.height`, `template.width`) eliminate container guessing and prevent Cumulative Layout Shift (CLS).
- **Paywall Exit Guard**: `AdPaywallGuard` intercepts both visual close button taps and Android hardware back / edge-swipe navigation.
- **Decoupled Purchase Suppression**: Clean boolean gating to instantly collapse inline ads and bypass fullscreen ads on any qualifying purchase.

---

## Quickstart

### 1. Stage 1 Initialization (`main.dart`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterAds.initialize(
    config: const FlutterAdsConfig(
      initialConcurrency: 1,
      subsequentConcurrency: 1,
    ),
  );

  runApp(const MyApp());
}
```

### 2. Stage 2 Placement Registration

```dart
void onRemoteConfigLoaded() {
  FlutterAds.registerPlacements([
    SampleAds.splashInterstitial,
    SampleAds.feedNative,
    SampleAds.mainBottomBanner,
  ]);
}
```

### 3. Composable Splash Screen

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  await Future.wait([
    FirebaseRemoteConfig.instance.fetchAndActivate(),
    AuthService.instance.restoreSession(),
    FlutterAds.waitFor(SampleAds.splashInterstitial),
  ]);

  if (!context.mounted) return;

  FlutterAds.show(
    SampleAds.splashInterstitial,
    onDismissed: () => Navigator.pushReplacementNamed(context, '/home'),
  );
}
```

### 4. Feed Native Ad

```dart
Widget buildNativeAdCard() {
  final template = NativeAdTemplate.medium;

  return Container(
    height: template.height,
    child: AdNativeView.templated(
      placement: SampleAds.feedNative,
      template: template,
    ),
  );
}
```

---

## AI Agent Integration Runbook (`skills.sh`)

[![skills.sh](https://skills.sh/b/shahid0/AdmobKit-flutter)](https://skills.sh/shahid0/AdmobKit-flutter)

This package includes a specialized AI Agent skill located at [`skills/flutter-ads/SKILL.md`](skills/flutter-ads/SKILL.md).

### Automatic Skill Installation (Any Agent)

Install the skill directly into your project or agent using the [`skills.sh`](https://skills.sh) CLI:

```bash
# Install to current project (Claude Code, Cursor, Antigravity, Copilot, etc.)
npx skills add shahid0/AdmobKit-flutter

# Or install globally across all projects
npx skills add shahid0/AdmobKit-flutter -g
```

### Prompt Formula for AI Agents

When directing AI coding assistants (Cursor, Claude Code, Antigravity, Copilot), use this prompt:

> *"Integrate `flutter_ads` using the `flutter-ads` skill. Configure two-stage initialization (Stage 1 in `main.dart`, Stage 2 in `RemoteConfigService`). For splash, use deterministic `waitFor` composition. Use `NativeAdTemplate` concrete dimensions for all native cards."*
