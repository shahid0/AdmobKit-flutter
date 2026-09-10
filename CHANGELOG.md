# Changelog

All notable changes to the `admob_kit_flutter` package will be documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.0.1

Initial public release of **AdmobKit-flutter** (`admob_kit_flutter`) — a deterministic, production-grade Google AdMob framework for Flutter engineered to eradicate ad race conditions, presentation collisions, and layout shifts.

### Features

- **0ms Instant Presentation Contract**: Global eager preloading queue (`waitFor`, `show`) ensuring ads are in memory and displayed with zero perceptible delay.
- **Two-Stage Initialization**: Light config boot in `main()` with decoupled UMP consent gating and background warm-up.
- **Built-in Google UMP Consent Support**: Complete consent collection flow with GDPR, EEA, and customizable geographic debug simulation.
- **Strict Presentation Concurrency Leasing**: Eliminates simultaneous ad collision races and black-screen UI freezes.
- **Zero-CLS Layout-Stable Widgets**:
  - `AdBannerView`: Layout-stable adaptive banner widget with reservation containers that prevent Cumulative Layout Shift.
  - `AdNativeView` & `AdNativeView.templated`: Platform native ad widgets bound to pre-dimensioned templates (`NativeAdTemplate.small`, `medium`, `big`).
  - `AdPaywallGuard`: Hardware back-button interceptor and paywall close-button wrapper with deterministic frequency capping and cooldown guards.
- **Extensible Architecture**:
  - Built-in analytics tracking contracts (`AdAnalyticsTracker`).
  - Diagnostic monitoring and health telemetry (`AdDiagnosticsTracker`, `AdDiagnosticReport`).
  - Production logger contracts (`AdLogger`) with zero spam.
  - Full support for Banner, Interstitial, Rewarded, Rewarded Interstitial, Native, and App Open ad formats.

