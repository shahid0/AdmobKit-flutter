# 0.1 engine update and release checks

Historical package-maintenance notes. For current app integration, use [README.md](README.md) and its public guides.
The counts and checks below record earlier development, not the current API contract or release status.

Internal status for the development branch. Version bump and publication are separate actions; this is not a release announcement. See [CHANGELOG.md](CHANGELOG.md) for user-facing changes.

## Implemented

The update extends the existing session, queue, pool and SDK driver. There is no alternate ad engine or compatibility layer.

- Deterministic consent/SDK/factory readiness and privacy-update barriers.
- Token-based fullscreen ownership, splash settlement without holding a display lock during loading, and stale-session cleanup.
- Width/orientation-aware adaptive banners using SDK sizing and refresh.
- 25 shared native template identities with Android/iOS asset binding.
- Global and placement-scoped `NativeAdStyle`, including CTA radius, through generated Pigeon transport.
- Retained inline freshness, explicit activity gates and fullscreen-native ownership.
- On-demand galleries, style controls and diagnostics in the example.
- Compact attribution/content layouts and Android high-density corner preservation.

Regenerate appearance transport with:

```bash
dart run pigeon --input pigeons/native_appearance.dart
```

Pigeon 27.3.0 is pinned to match the current SDK's analyzer/meta constraints. No runtime dependency was added for appearance or visibility.

## Verification recorded during implementation

- 171 package tests and 64 example tests passed.
- 18 Android native unit tests passed; the example debug APK built.
- Android fixtures covered all templates, missing assets, LTR/RTL, font measurement, density, style/reset and fullscreen resizing.
- Swift sources type-checked against installed Flutter/Google Mobile Ads headers.
- The iOS example built and ran on a physical iPhone. Test native, banner and SDK fullscreen loads were observed; an interstitial displayed and dismissed after the device ad blocker was disabled.
- Earlier local CocoaPods build failures are no longer the current blocker.

These are recorded checks, not certification of every live template, accessibility setting or AdMob policy. Mocked transport/layout tests do not replace device verification.

## Before stable 0.1.0

1. Resolve the iOS Auto Layout warnings observed around fixed rating/price widths. Verify optional metadata does not produce broken constraints with real SDK assets.
2. Review all 25 templates on Android and iOS with live test creatives: missing assets, rotation, large text, media/video, attribution and AdChoices interaction.
3. Exercise fullscreen-native coverage, background/foreground, retained-page activity, disposal and live appearance changes on devices.
4. Verify production privacy messages/entry points, ad unit configuration and app-owned presentation policy in a consuming app.
5. Run package/example analysis and tests plus native tests/builds on the release commit.
6. Set release metadata consistently, finalize the changelog and publish only after the checks above.

The plugin deployment target remains iOS 13; the example app targets iOS 15. Toolchain versions and signing configuration are not part of the public API.
