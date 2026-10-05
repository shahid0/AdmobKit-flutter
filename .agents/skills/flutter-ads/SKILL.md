---
name: flutter-ads
description: >-
  Production-grade Google Mobile Ads (AdMob) orchestration in Flutter with admob_kit_flutter.
  Use when integrating splash, interstitial, rewarded, app-open, adaptive banner, or native ads,
  paywall exit guards, GDPR/UMP consent, tab-deferred loading, or ad revenue/analytics wiring.
  Enforces the 0ms show contract, deterministic settlement (waitFor), two-stage initialization,
  priority-tiered preloading, and native-measured ad containers.
---

# AdmobKit Integration Runbook

**Package:** `admob_kit_flutter` · **Facade:** `AdmobKit` · **Widgets:** `AdBannerView`, `AdNativeView`, `AdPaywallGuard`

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
```

Always use this exact import and the `AdmobKit` facade.

---

## The 4 Architectural Laws

1. **0ms Show Contract** — `AdmobKit.show(placement, onDismissed: …)` is strictly non-blocking. If cached in memory, it displays instantly. If unready, expired, or offline, `onDismissed` fires immediately (0ms delay). Never block user navigation on an ad request.
2. **Deterministic Settlement** — Never guess ad readiness with `Timer` or `Future.delayed`. Await `AdmobKit.waitFor(placement)` (returns `Future<bool>`), composed with auth/config futures via `Future.wait`.
3. **Immediate-Display Priority** — The on-screen ad always wins network priority. Visible widget leases and `waitFor` calls automatically promote to the `immediate` tier, preempting background preloads.
4. **Native-Measured Layout** — Provide bounded width >=320 logical pixels and let inline ads size themselves from their SDK assets and Flutter text scale. `template.height` is only a loading estimate. Fullscreen hosts require bounded height >=320 and enough room for copy and media; keep navigation outside ad assets.

---

## 5-Step Implementation Workflow

### Step 1: Declare Placements (`lib/ads/app_ads.dart`)

```dart
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

abstract final class AppAds {
  static const splashInterstitial = InterstitialPlacement(
    id: 'splash_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
    isSplash: true,
    loadOnce: true,
  );

  static const feedNative = NativePlacement(
    id: 'feed_native',
    template: NativeAdTemplate.cardContentTop,
    androidId: AdMobTestIds.nativeAndroid,
    iosId: AdMobTestIds.nativeIos,
    style: NativeAdStyle(
      callToActionBackground: 0xFF2563EB,
      callToActionText: 0xFFFFFFFF,
      callToActionCornerRadius: 8,
    ),
  );

  static const bottomBanner = BannerPlacement(
    id: 'bottom_banner',
    androidId: AdMobTestIds.bannerAndroid,
    iosId: AdMobTestIds.bannerIos,
  );

  static const paywallExitInterstitial = InterstitialPlacement(
    id: 'paywall_exit_interstitial',
    androidId: AdMobTestIds.interstitialAndroid,
    iosId: AdMobTestIds.interstitialIos,
  );
}
```

### Step 2: Stage 1 Cold Boot (`lib/main.dart`)

Initialize consent and GMA SDK at cold boot, before any route mounts:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final boot = AdmobKit.initialize(
    config: AdmobKitConfig(
      initialConcurrency: 1,
      subsequentConcurrency: 1,
      isPremium: () => UserStore.isVip, // Universal VIP suppression
    ),
  );

  runApp(const MyApp());

  try {
    await boot;
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}
```

### Step 3: Stage 2 Placement Registration

Register placements when IDs resolve (e.g. Remote Config). Register one-time placements (onboarding/splash) conditionally:

```dart
void onRemoteConfigLoaded({required bool isFirstLaunch}) {
  AdmobKit.registerPlacements([
    AppAds.splashInterstitial,
    AppAds.feedNative,
    AppAds.bottomBanner,
    if (isFirstLaunch) AppAds.onboardingNative, // loadOnce placement
  ]);
}
```

### Step 4: Mount Widgets & Wire Triggers

Use the Decision Table below to mount appropriate widgets or fullscreen triggers.

### Step 5: Verify against Invariant Constraints

Audit against the negative constraints and run the verification checklist.

---

## Decision Table — What to Mount Where

| Surface / Goal | SDK Pattern |
| :--- | :--- |
| **Cold-start splash** | `await AdmobKit.waitFor(splash)` + `AdmobKit.show(splash, onDismissed: next)` (`isSplash: true, loadOnce: true`) |
| **Sticky screen banner** | `AdBannerView(placement: bottomBanner)` |
| **In-feed banner** | `BannerPlacement(sizing: BannerSizing.inlineAdaptive(maxHeight: 160))` + `AdBannerView` |
| **In-content native card** | `AdNativeView(placement: feedNative)` with bounded width and content-sized height |
| **Fullscreen native** | `NativePlacement(template: NativeAdTemplate.fullscreen)` + `AdNativeView` in bounded `Scaffold` |
| **Feature / Reward unlock** | `AdmobKit.show(rewarded, onRewardGranted: (amt, type) => grant(), onDismissed: refresh)` |
| **Paywall close & back** | `AdPaywallGuard(placement: exitPlacement, onDismiss: () => Navigator.pop(context), builder: ...)` |
| **Tab / PageView ads** | `IndexedStack` (automatic deferral) or pass `active: pageIndex == currentPage` on `AdNativeView` |
| **App Open on resume** | Gate inside `didChangeAppLifecycleState`: `state == resumed && !AdmobKit.isShowingAd` |
| **VIP / In-App Purchases** | Set `isPremium: () => hasActiveSub` in `AdmobKitConfig` — auto-collapses all ads |

---

## Key Recipes

### Deterministic Splash Sequence

```dart
Future<void> handleSplashSequence(BuildContext context) async {
  await Future.wait([
    RemoteConfigService.instance.fetch(),
    AuthService.instance.restoreSession(),
    AdmobKit.waitFor(AppAds.splashInterstitial),
  ]);

  if (!context.mounted) return;

  AdmobKit.show(
    AppAds.splashInterstitial,
    onDismissed: () => Navigator.pushReplacementNamed(context, '/home'),
  );
}
```

### Content-Sized Native Feed Card

```dart
Widget buildFeedNativeAd() {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: const AdNativeView(placement: AppAds.feedNative),
  );
}
```

### Live Dynamic Theming / Dark Mode

```dart
await AdmobKit.setNativeStyle(
  const NativeAdStyle(
    background: 0xFF1E293B,
    headline: 0xFFF8FAFC,
    body: 0xFF94A3B8,
    callToActionBackground: 0xFF3B82F6,
    callToActionText: 0xFFFFFFFF,
    callToActionCornerRadius: 100, // Pill button
  ),
);
```

### Paywall Exit Guard

```dart
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(),
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: triggerDismiss,
      ),
    ),
    body: const PaywallContent(),
  ),
);
```

---

## Invariant Negative Constraints (Anti-Patterns)

- ❌ **NEVER use `Timer` or `Future.delayed` for ad readiness** — use `AdmobKit.waitFor(placement)`.
- ❌ **NEVER manually instantiate `NativeAd`, `BannerAd`, or `AdWidget`** — use `AdNativeView` / `AdBannerView`.
- ❌ **NEVER call `leaseInlineAd` from application code** — widgets handle leasing internally.
- ❌ **NEVER fire ads before or over the UMP consent form**.
- ❌ **NEVER fix inline native height to `template.height`** — it is a loading estimate; allow the measured creative to grow.
- ❌ **NEVER register one-time (`loadOnce: true`) placements unconditionally on subsequent app launches**.
- ❌ **NEVER trigger App Open ads without checking `!AdmobKit.isShowingAd`**.
- ❌ **NEVER mount `AdNativeView` or `AdBannerView` inside unbounded horizontal constraints**.

---

## Verification Checklist

1. `flutter analyze` passes with 0 issues.
2. Single import: `import 'package:admob_kit_flutter/admob_kit_flutter.dart';`.
3. Deterministic settlement: `waitFor` used for splash/gates, returning a handled `bool`.
4. Stage 1 in `main()`, Stage 2 after IDs resolve.
5. All native hosts have bounded width >=320 logical pixels; inline heights follow measured content.
6. Fullscreen natives mounted in bounded `Scaffold` with custom dismiss control outside ad assets.
7. Paywall guarded against both hardware back and close button via `AdPaywallGuard`.
8. App Open gated by `!AdmobKit.isShowingAd`.
9. `flutter test` passes.
