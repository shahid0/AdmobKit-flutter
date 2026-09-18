# Reference App Blueprint — Full SDK Usage

A production-shaped ad architecture for a real app, mapped surface-by-surface onto AdmobKit calls. This is the **usage reference for every screen shape** an agent will meet: what the SDK call is at each point. App navigation, click-counting, and Remote Config plumbing are the host app's job — wherever a snippet below says "your logic," that's the seam.

The running example: an app with splash → (onboarding for new users) → home with tab shells → paywall. Every ad touchpoint from the brief is covered.

---

## Placement inventory (the full map)

Before any code: enumerate every surface, its format, lifecycle, and registration strategy. This table IS the Stage-2 registration list.

| Surface | Placement | Format | `loadOnce` | `isSplash` | Priority | Registered |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Splash bottom | `splashBigNative` | Native big | `true` | `true` | `splash` | Always |
| Splash gate | `splashGate` | Interstitial OR AppOpen | `true` | `true` | `splash` | Always |
| Onboarding cards | `onboardingNative` | Native big | `true` | — | `immediate` | **First-run only** |
| Onboarding mid-flow | `onboardingInterstitial` | Interstitial | `true` | — | `high` | **First-run only** |
| Home bottom | `homeBanner` | Banner | `false` | — | `medium` | Always |
| Tab/sub-screen natives | `tabNative` | Native medium | `false` | — | `medium` | Always |
| Click-threshold interstitial | `clickInterstitial` | Interstitial | `false` | — | `immediate` | Always |
| Mode-switch interstitial | `modeSwitchInterstitial` | Interstitial | `false` | — | `medium` | Always |
| Locked feature A | `featureRewarded` | Rewarded | `false` | — | `medium` | Always |
| Locked feature B | `featureRewardedInterstitial` | Rewarded Interstitial | `false` | — | `medium` | Always |
| Remote-gated feature | `featureGated` | Rewarded OR Rewarded Interstitial | `false` | — | `medium` | Always |
| Paywall close | `paywallExitInterstitial` | Interstitial | `false` | — | `high` | Always |

Two native card slots visible simultaneously on one screen? Add `placementCapacities: {'tabNative': 2}` — and only then.

---

## Stage 2 registration — conditional, per install

```dart
// remote_config_service.dart
void registerAdPlacements() {
  final rc = RemoteConfigService.instance;

  AdmobKit.registerPlacements([
    // — Always-present surfaces —
    AppAds.splashBigNative,
    // Splash gate format is REMOTE-CONTROLLED: register the one RC chose.
    // (Both variants defined in AppAds; exactly one goes in.)
    if (rc.splashGateFormat == 'appOpen') AppAds.splashGateAppOpen
    else AppAds.splashGateInterstitial,
    AppAds.homeBanner,
    AppAds.tabNative,
    AppAds.clickInterstitial,
    AppAds.modeSwitchInterstitial,
    AppAds.featureRewarded,
    AppAds.featureRewardedInterstitial,
    // Remote-gated rewarded format: RC picks the variant at feature-use time,
    // so register BOTH (each shows only when its trigger fires).
    AppAds.featureRewarded,
    AppAds.featureRewardedInterstitial,

    // — First-run-only surfaces: THE loadOnce trap in action —
    // loadOnce consumption is permanent per install. Registering these
    // unconditionally wastes a load on every returning user and leaves
    // phantom consumed state if the flow is skipped.
    if (rc.isFirstLaunch) ...[
      AppAds.onboardingNative,
      AppAds.onboardingInterstitial,
    ],
  ]);
}
```

**If first-run status isn't known at Stage-2 time:** register the onboarding placements lazily, at the moment onboarding becomes reachable (e.g. right after auth reports "no session"). `registerPlacements` is callable multiple times.

---

## Splash — big native pinned at bottom + remote-controlled fullscreen gate

The splash shows a big native card at the bottom **and** a fullscreen gate whose format (Interstitial vs App Open) is decided by Remote Config. Both are primed at boot; neither delays navigation.

Native at bottom — the widget owns everything. Both splash placements ride the dedicated `splash` tier (`isSplash: true` on both), and the queue's intra-tier rule guarantees ordering: **inline (the native) always dispatches before fullscreen (the gate)** within the same tier, so the visible card wins bandwidth and the gate loads right behind it:

```dart
// app_ads.dart — SDK usage only
static const splashBigNative = NativePlacement.big(
  id: 'splash_big_native',
  androidId: AdMobTestIds.nativeAndroid,
  iosId: AdMobTestIds.nativeIos,
  isSplash: true,   // splash tier — loads before/alongside the gate
  loadOnce: true,   // one splash per install → one native load, ever
);
```

Widget mount (splash layout is app-owned):

```dart
// splash_screen.dart — bottom of the splash layout
SizedBox(
  height: NativeAdTemplate.big.height, // 300dp — reserved, zero CLS
  width: double.infinity,
  child: const AdNativeView.templated(
    placement: AppAds.splashBigNative,
    template: NativeAdTemplate.big,
  ),
)
```

Deterministic gate — compose with the app's own startup futures:

```dart
// splash_screen.dart — SDK usage only; Remote Config / auth futures are app-owned
await Future.wait([
  RemoteConfigService.instance.ready,          // app logic
  AuthService.instance.restoreSession(),       // app logic
  AdmobKit.waitFor(AppAds.splashGate),         // ← the SDK seam
]);
if (!context.mounted) return;

AdmobKit.show(
  AppAds.splashGate,                           // whichever variant RC registered
  onDismissed: () => _proceed(),               // app navigation
);
// No timer, no fallback delay. If the gate never loaded, onDismissed
// already fired and the user proceeded at 0ms.
```

---

## Onboarding — new users only

Cards get natives; one interstitial fires mid-flow (e.g. after step 2 of 3). Both placements exist in `AppAds` but were registered **only for first-run installs** — on every other install these calls are no-ops (premium-style pass-through: `show` → immediate `onDismissed`), so the same screen code is safe everywhere.

```dart
// onboarding_card.dart — SDK usage only; carousel logic is app-owned
SizedBox(
  height: NativeAdTemplate.big.height,
  child: const AdNativeView.templated(
    placement: AppAds.onboardingNative,
    template: NativeAdTemplate.big,
  ),
)
```

```dart
// onboarding_screen.dart — after the user completes a mid-flow step
// SDK usage only; step/progress logic is app-owned
AdmobKit.show(
  AppAds.onboardingInterstitial,
  onDismissed: () => _goToNextStep(),  // app navigation
);
```

---

## Home shell — sticky banner + tab natives

```dart
// home_shell.dart — SDK usage only; tab state is app-owned
Scaffold(
  body: IndexedStack(
    index: currentTab,
    children: const [
      FeedTab(),     // contains AdNativeView(placement: AppAds.tabNative) — defers until front
      FocusTab(),    // same — hidden tabs cost zero network
      ProfileTab(),
    ],
  ),
  bottomNavigationBar: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const AdBannerView(placement: AppAds.homeBanner), // collapses if premium
      NavigationBar(...),
    ],
  ),
)
```

Tab content with a native card (works the same in a pushed sub-screen):

```dart
// feed_tab.dart — SDK usage only; list layout is app-owned
Container(
  height: NativeAdTemplate.medium.height, // 130dp
  child: const AdNativeView.templated(
    placement: AppAds.tabNative,
    template: NativeAdTemplate.medium,
  ),
)
```

---

## Click-threshold interstitial — counting is app logic, firing is SDK

Every navigation click bumps a counter (app-owned). At the threshold, fire the ad — the 0ms contract means an unready ad never blocks the user's action:

```dart
// app-owned counter; SDK seam only
void onNavigationClick() {
  if (++_clickCount < RemoteConfigService.instance.adThreshold) return;
  _clickCount = 0;

  AdmobKit.show(
    AppAds.clickInterstitial,
    onDismissed: () {}, // action already proceeded; ad is fire-and-continue
  );
}
```

Because `show` is strictly non-blocking, the user's tap is honored even if the ad is still downloading — no gate, no spinner.

---

## Mode switches — interstitials on heavy actions

Filter changes, video↔image toggles, layout switches. Same shape as the click threshold, but keyed to the action instead of a counter:

```dart
// SDK usage only; the switch itself is app logic
void onModeSwitch(AppMode newMode) {
  setState(() => mode = newMode); // apply the switch FIRST — never block UX
  AdmobKit.show(AppAds.modeSwitchInterstitial);
}
```

Rule: apply the user's action immediately; let the ad (or its absence) ride on top. Only gate the *result navigation* behind `onDismissed` when the flow genuinely requires sequencing (like splash).

---

## Locked features — rewarded, rewarded interstitial, and remote control

Fixed rewarded:

```dart
// SDK usage only; entitlement granting is app logic
AdmobKit.show(
  AppAds.featureRewarded,
  onRewardGranted: (amount, type) => FeatureGate.unlock(), // app logic
  onDismissed: () => setState(() {}),                       // refresh UI
);
```

Fixed rewarded interstitial:

```dart
AdmobKit.show(
  AppAds.featureRewardedInterstitial,
  onRewardGranted: (amount, type) => FeatureGate.unlock(),
  onDismissed: () => setState(() {}),
);
```

**Remote-controlled format** — RC decides whether a feature sits behind rewarded or rewarded interstitial. Both placements are registered; the trigger site reads RC and fires the chosen one:

```dart
// SDK usage only; the RC lookup + gating state is app logic
void onLockedFeatureTapped(LockedFeature feature) {
  final useRewardedInterstitial =
      RemoteConfigService.instance.rewardFormatFor(feature.id) == 'rewardedInterstitial';

  AdmobKit.show(
    useRewardedInterstitial ? AppAds.featureRewardedInterstitial : AppAds.featureRewarded,
    onRewardGranted: (amount, type) => FeatureGate.unlock(),
    onDismissed: () {
      if (!FeatureGate.isUnlocked(feature.id)) {
        // Dismissed without earning → keep feature locked (app logic)
      }
      setState(() {});
    },
  );
}
```

The `onRewardGranted` / dismissal split is the whole contract: reward callback = earned; bare dismissal = not earned. Don't unlock in `onDismissed`.

---

## Paywall — close button and hardware back fire the same exit ad

```dart
// paywall_screen.dart — SDK usage only; paywall UI/purchase logic is app-owned
AdPaywallGuard(
  placement: AppAds.paywallExitInterstitial,
  onDismiss: () => Navigator.of(context).pop(), // app navigation
  builder: (context, triggerDismiss) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: triggerDismiss, // identical path as hardware back
      ),
    ),
    body: PaywallContent(...),
  ),
)
```

Purchasers bypass everything: `isPremium` at init makes `AdPaywallGuard` pass through at 0ms — no branch needed in UI code.

---

## App lifecycle — resume App Open only on real backgrounding

The trap: lifecycle events fire on transient interruptions (permission dialogs, share sheets, in-app browsers). Gate on a real background dwell, not a raw resume event. All thresholds and cooldown windows are app policy.

```dart
// app_lifecycle_observer.dart — SDK usage only; dwell/cooldown policy is app logic
class AppOpenCoordinator with WidgetsBindingObserver {
  DateTime? _pausedAt;
  DateTime? _lastShownAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:     // iOS app switcher also lands here
        _pausedAt = DateTime.now();
      case AppLifecycleState.resumed:
        _onResumed();
      default:
        break; // inactive/detached — ignore
    }
  }

  void _onResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (pausedAt == null) return; // resumed without a real pause (transient)

    final dwell = DateTime.now().difference(pausedAt);
    final enoughDwell = dwell >= const Duration(seconds: 5);        // app policy
    final cooldownOk = _lastShownAt == null ||
        DateTime.now().difference(_lastShownAt!) >= const Duration(minutes: 3); // app policy

    if (enoughDwell && cooldownOk && !AdmobKit.isShowingAd) {       // ← SDK gate
      _lastShownAt = DateTime.now();
      AdmobKit.show(AppAds.appOpen);                                 // ← SDK seam
    }
  }
}
```

Three SDK requirements live in that one condition: a **real** pause preceded the resume, `AdmobKit.isShowingAd` is false (no firing over another fullscreen, no firing over a modal/paywall), and the coordinator holds its own cooldown. Register the observer in the root widget's state; also suppress on first launch — the splash gate already covers cold start.

---

## Premium is one callback

```dart
await AdmobKit.initialize(config: const AdmobKitConfig(
  isPremium: () => PurchaseService.hasEntitlement, // app logic
));
```

Every surface above then behaves correctly with zero per-screen branches: preloads skipped, `show` → immediate `onDismissed` (flows proceed), widgets collapse to `SizedBox.shrink`, `AdPaywallGuard` passes through.

---

## The wiring rules this blueprint demonstrates

1. **Placement table first, code second** — enumerate surfaces → formats → `loadOnce`/`isSplash`/priority → registration conditionality. That table is your `registerPlacements` call.
2. **One-time screens register conditionally** — never unconditionally for first-run-only surfaces.
3. **Widgets at the edges, `show` at the seams** — `AdNativeView`/`AdBannerView`/`AdPaywallGuard` in layout; `AdmobKit.show`/`waitFor` at navigation and action points; nothing else.
4. **App logic owns counting, RC, and policy** — thresholds, cooldowns, dwell windows, format selection live in the host app; the SDK owns timing, state, exclusivity, and retries.
5. **Never block UX on an ad** — apply the user's action first; sequence only through `onDismissed` when the flow genuinely requires it.
6. **Reward = `onRewardGranted`, nothing else** — bare dismissal never unlocks.
7. **Format switching via registered variants** — RC-controlled formats (splash gate, rewarded-vs-rewarded-interstitial) keep both placements registered and select at trigger time.
