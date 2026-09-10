# AdmobKit-flutter Example App (TaskFlow Pro)

A complete, production-grade Flutter task management and productivity application demonstrating the real-world integration of **AdmobKit-flutter** (`admob_kit_flutter`).

---

## What This Example Demonstrates

This app simulates a real revenue-generating mobile product (**TaskFlow Pro**) with zero-latency ad placements, background consent handling, zero layout shifts, and paywall guards:

1. **Deterministic 0ms Splash Screen Flow** (`SplashScreen`)
   - Eagerly initializes AdmobKit.
   - Waits for splash interstitial (`AdmobKit.waitFor(SampleAds.splashInterstitial)`).
   - Shows the interstitial seamlessly without blocking UI boot.
2. **Layout-Stable Native Ads in Feed** (`AdNativeView.templated`)
   - Demonstrates `NativeAdTemplate.medium` embedded between task items.
   - Fixed height reservations guarantee zero Cumulative Layout Shift (CLS).
3. **Adaptive Bottom Banner** (`AdBannerView`)
   - Integrated with standard banner height reservations.
   - Automatic refresh and error placeholder fallbacks.
4. **Hardware Back & Close Paywall Guard** (`AdPaywallGuard`)
   - Traps physical Android back button and paywall close button.
   - Presents an exit interstitial when non-premium users dismiss the paywall.
5. **App Open Background Resume** (`main.dart`)
   - Uses `WidgetsBindingObserver` to detect app lifecycle changes.
   - Displays `SampleAds.appOpen` on app resume if no other ad is active.
6. **Diagnostics & Analytics Telemetry Console**
   - In-app debug drawer displaying real-time callbacks (`onAdLoaded`, `onAdDisplayed`, `onPaidEvent`, `onDiagnosticReport`).
   - One-tap access to Google Ad Inspector.

---

## Running the Example

### 1. Prerequisites
- Flutter SDK `^3.10.0`
- Android Studio / Xcode

### 2. Platform Setup
The example app is pre-configured with Google's official sample AdMob Application IDs:
- **Android**: `ca-app-pub-3940256099942544~3347511713` (in `android/app/src/main/AndroidManifest.xml`)
- **iOS**: `ca-app-pub-3940256099942544~1458002511` (in `ios/Runner/Info.plist`)

> **Note**: These sample IDs only serve test ads and are safe for development.

### 3. Launching
```bash
cd example
flutter pub get
flutter run
```

---

## Architecture Overview

```
example/
├── lib/
│   ├── config/
│   │   └── sample_ads.dart      # Canonical AdmobKit placement definitions
│   ├── screens/
│   │   ├── splash_screen.dart   # Deterministic splash preload and 0ms display
│   │   ├── paywall_screen.dart  # AdPaywallGuard integration
│   │   └── tabs/                # Native ads in lists, banner views, interstitial triggers
│   ├── state/
│   │   └── task_store.dart      # Premium status toggle & telemetry log buffer
│   └── main.dart                # Two-stage init, lifecycle App Open ad trigger
```

