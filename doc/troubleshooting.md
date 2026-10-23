# Troubleshooting

Diagnose with the public status API, logs, and Google Ad Inspector. You should not need to read package source to fix an integration.

## Diagnostic workflow

1. Check `AdmobKit.initializationState`. Ads are requested only in `ready`.
2. Make sure `initialize()` is called before `registerPlacements()` and before ad widgets mount.
3. Make sure the device has a working connection, without VPN filters or ad blockers.
4. Turn on `logLevel: AdLogLevel.verbose` and an `AdDiagnosticsTracker` to see each request, load, retry, and failure.
5. Open Ad Inspector to check ad units and mediation on the device.

```dart
void inspectAdIntegration() {
  AdmobKit.openAdInspector((error) {
    if (error != null) debugPrint('Ad Inspector error: $error');
  });
}

void logPlacementState(AdPlacement placement) {
  debugPrint('Placement ${placement.id} state: ${AdmobKit.getState(placement)}');
}
```

## AdMob error codes

| Code | Name | Usual cause | What to do |
| :--- | :--- | :--- | :--- |
| `0` | Internal error | Platform or network stack failure | Check logcat or the Xcode console; check connectivity |
| `1` | Invalid request | Missing app ID, wrong unit ID, or a unit ID of a different format | Check the unit ID matches the placement type, and the app ID in `AndroidManifest.xml` and `Info.plist`. AdmobKit never retries this code |
| `2` | Network error | No connection or a timed-out request | Check the network. On slow networks use `AdTimeoutConfig.emergingMarkets` |
| `3` | No fill | No inventory for this request | Expected for new accounts and some regions. AdmobKit retries with backoff; do not add your own retry loop |

## Common problems

### No ads appear

- The app ID is in `AndroidManifest.xml` and `Info.plist`, and the app was rebuilt after adding it.
- You use test unit IDs (`AdMobTestIds`) during development.
- `initializationState` is not `consentDenied` or `failed`.
- `AdmobKit.isUserPremium` is `false`.
- Ad widgets have bounded width: at least 320 logical pixels for native ads.

### `waitFor` or `waitForAll` returns `false`

`waitFor` returns `false` when the ad definitively cannot come:
- consent was denied, or the user is premium;
- the device is offline (the load stays queued and resumes when the network returns);
- retries ran out after no-fill or network errors;
- a `loadOnce` placement was already used;
- your optional `timeout` budget ran out.

Check `initializationState` and `getState(placement)` to see which. A later `waitFor` call requests again.

### The first ad at launch is missing

`canRequestAds` is `false` until consent and SDK setup finish. Do not check it to decide whether to wait; call `waitFor`, which waits for both.

### An ad shows on the wrong screen, or two ads show back to back

AdmobKit shows a fullscreen ad only when you call `show`, and never two at once. Back-to-back ads come from app code calling `show` at consecutive transitions, for example after a splash ad and again when a paywall closes. Add a frequency rule in your app.

### Adaptive banners load only after their screen opens

This is expected: an adaptive banner's size depends on its measured width, so it loads when its widget lays out. Inline adaptive banners reserve their height and show a "Loading ad" placeholder; anchored banners reserve nothing. For a banner that must be ready before its screen opens, use a fixed size such as `BannerSizing.standard()`.

### A fixed banner never requests

The host is narrower than the banner, for example `leaderboard()` (728 wide) on a phone. Choose a size that fits, or use adaptive sizing.

### Banner layout errors

- `AdBannerView` needs a bounded width. Inside a `Row` or other unbounded parent, wrap it in `Expanded` or pass `width:`.
- Do not force a height on `AdBannerView`; its sizing decides the height.

### Native layout errors

- `AdNativeView` needs a bounded width of at least 320 logical pixels.
- Let inline templates size themselves; `template.height` is only a loading estimate.
- Fullscreen templates need a bounded height of at least 320 and room for their media and text.
- If the space is too small, show your normal content instead of the ad. Never hide the attribution badge, AdChoices icon, or call-to-action.

### An ad reloads every time I return to a page

Ad widgets keep their ad across covered routes, tab switches, and scrolling. A reload means the widget was rebuilt as a new widget: its key or placement changed. Keep both stable.

### Premium users still see an ad

`isPremium` is read at each request and presentation, but widgets already on screen rebuild only when your app rebuilds them. Rebuild after a purchase. Do not call `dispose()` for premium changes.

### Release builds crash or show no ads

With R8 shrinking enabled, add keep rules to `android/app/proguard-rules.pro`:

```proguard
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
```

On iOS, make sure `Info.plist` contains `GADApplicationIdentifier` and the `SKAdNetworkItems` Google lists.

## Reporting a bug

Include:
1. AdmobKit and Flutter versions.
2. Platform, OS version, and device model.
3. The placement configuration and template.
4. Verbose logs and diagnostic events around the problem.
5. Whether it reproduces with Google's test unit IDs.

Remove private keys and personal data before sharing logs.
