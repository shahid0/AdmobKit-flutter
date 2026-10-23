# Troubleshooting

Use public status getters, logger output, and Ad Inspector for diagnosis.
Do not inspect package source code to diagnose normal integration problems.

## Diagnostic Workflow

Follow these steps to find integration problems:

1. Examine `AdmobKit.initializationState`.
2. Make certain that `initialize` completed before you register placements or mount widgets.
3. Verify that device network access is active. Disable VPN filters and ad blockers.
4. Open Ad Inspector to examine the reported error.

```dart
void inspectAdIntegration() {
  AdmobKit.openAdInspector((error) {
    if (error != null) {
      debugPrint('Ad Inspector error: $error');
    }
  });
}

void logPlacementState(AdPlacement placement) {
  final state = AdmobKit.getState(placement);
  debugPrint('Placement ${placement.id} state: $state');
}
```

## AdMob Error Codes

Google Mobile Ads SDK returns these standard error codes:

| Code | Name | Cause | Correct Action |
| :--- | :--- | :--- | :--- |
| `0` | `ERROR_CODE_INTERNAL_ERROR` | OS failure, platform view failure, or network stack failure. | Examine device logs in logcat or Xcode console. Verify that the device has network connectivity. |
| `1` | `ERROR_CODE_INVALID_REQUEST` | Missing App ID, mismatched ad format, or invalid ad unit ID. | Verify that the unit ID matches the placement format. Verify manifest and `Info.plist` IDs. |
| `2` | `ERROR_CODE_NETWORK_ERROR` | Device has no internet connection, or connection timed out. | Verify device network. In low-bandwidth regions, use `AdmobKitTimeoutConfig.emergingMarkets()`. |
| `3` | `ERROR_CODE_NO_FILL` | The ad server has no ad inventory available for this request. | Expected behavior for new accounts and unverified apps. Use official Google test IDs during development. |

> [!NOTE]
> `ERROR_CODE_NO_FILL` (Code 3) is not an engine defect.
> It means Google ad servers currently have no matching inventory for that unit.
> Never write custom loops to retry a failed ad request.
> The engine handles retries automatically with exponential backoff.

## Common Problems and Solutions

### 1. No Ads Appear on Screen

- Verify that the AdMob App ID is present in `AndroidManifest.xml` and `Info.plist`.
- Verify that you use test ad unit IDs during development.
- Make certain that `AdmobKit.initialize()` runs before you call `registerPlacements()` or mount ad widgets.
- Examine `AdmobKit.initializationState`. If status is `consentDenied`, the engine blocks ad requests.
- Verify that `isUserPremium` is false.
- Disable active VPN connections, DNS filters, and ad blocker profiles.
- Make certain that host widgets provide bounded dimensions.

### 2. Missing First Ad on App Launch

`AdmobKit.canRequestAds` is false before consent and SDK initialization finish.
Do not abort app startup when `canRequestAds` returns false initially.
Do not poll `AdmobKit.isReady()`.

Instead, use `AdmobKit.waitFor()` for cold start flows:

- `waitFor` pauses until consent resolves, SDK initializes, and the ad buffers.
- If the ad is not ready before the timeout expires, `waitFor` returns false.
- Your app then proceeds immediately without showing an ad.

### 3. `waitFor()` Returns False

A false return value means that no buffered ad was available when the timeout expired.
Common causes:

- User denied consent during the UMP consent form.
- The user has premium ad-free entitlement.
- Google ad servers returned No Fill (Code 3).
- The network request exceeded the timeout duration.
- The placement configured `loadOnce: true` and the single ad was already displayed.

To diagnose, check `AdmobKit.initializationState` and `AdmobKit.getState(placement)`.

### 4. Banner Layout Errors and Overflows

- An `AdBannerView` requires bounded horizontal width.
- Do not place `AdBannerView` inside an unconstrained horizontal `Row`.
- Do not place `AdBannerView` inside an unconstrained vertical `Column` without bounded height.
- Wrap `AdBannerView` with `Expanded` or `SizedBox(width: double.infinity)`.
- Adaptive banners reserve their maximum measured height automatically.
- Do not assign a hardcoded estimated height to `AdBannerView`.

### 5. Native Ad Layout and Truncation Errors

- Native ad containers require at least 320 logical pixels of bounded width.
- For inline native templates, let content determine the widget height.
- Do not use `template.height` as a rigid container height constraint.
- For fullscreen native templates, provide bounded height and sufficient space for text and media.
- If available screen space is too small, hide the ad widget and show standard app content.
- Never hide required AdMob assets such as the Ad attribution badge or CTA button.
- Review [Native ads](native-ads.md) for known policy truncation limits.

### 6. Retained Tabs and Hidden Pages

Widgets like `PageView`, `TabBarView`, and `IndexedStack` keep inactive pages alive in memory.
Inactive ad views can waste memory and trigger background refreshes.

To prevent background activity:

- Pass the page visibility flag to the `active` parameter of `AdBannerView` and `AdNativeView`.
- When `active` is false, the widget detaches from layout rendering.
- When the user navigates back to the tab, set `active: true` to resume rendering.

### 7. Premium Access Changes

- The `isPremium` callback supplies entitlement to the engine.
- The callback does not notify existing UI widgets automatically.
- Rebuild your ad host widgets when user purchase state changes.
- Do not call `AdmobKit.dispose()` when the user buys an entitlement.
- Re-mounting ad widgets or calling `show()` will respect the updated `isPremium` value.

### 8. Release Build Errors and Minification

When building a release APK or AAB with R8 code shrinking enabled, classes can be stripped.
If release builds crash on startup or fail to show ads:

Add these keep rules to your `android/app/proguard-rules.pro` file:

```proguard
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.mediation.** { *; }
```

Make certain your `android/app/build.gradle` references the ProGuard file:

```groovy
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
    }
}
```

On iOS, make certain `Info.plist` contains `GADApplicationIdentifier` and all required `SKAdNetworkItems`.

### 9. Banners Load Only After Mounting

- **Symptom**: Diagnostics show no banner request after `registerPlacements()`, and the banner appears a moment after its screen opens.
- **Cause**: This is expected. `registerPlacements()` preloads fullscreen and native placements only. An adaptive banner's size depends on the measured container width and orientation, so `AdBannerView` requests it when it lays out.
- **Solution**: Mount `AdBannerView` where the banner shows and let it load. Use `reserveSpace` to avoid a layout jump while it loads. If content must be ready before the screen opens, use `NativePlacement` with `AdNativeView`. There is no public banner preload.

## Submitting a Bug Report

If an issue continues after you complete this diagnostic workflow, collect this evidence:

1. AdmobKit package version and Flutter SDK version.
2. Target platform (Android API level or iOS version) and device model.
3. Exact placement configuration and template name.
4. Initialization state logs and diagnostic events from `AdmobKit.watchState()`.
5. Confirmation of whether the issue reproduces with official Google test ad unit IDs.

Remove private keys, API secrets, and user personal data before you submit the report.
