# Platform Setup

AdmobKit supports Android (API 24 and later) and iOS (13.0 and later).
It requires Dart 3.11.5 or later and Flutter 3.41.0 or later.
An AdMob application identifier is different from an ad unit identifier:
- Application identifiers contain a tilde: `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`.
- Ad unit identifiers contain a slash: `ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`.

## Android Configuration

Add your AdMob application identifier inside the `<application>` tag in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <!-- Sample Google test application ID -->
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3940256099942544~3347511713" />
    </application>
</manifest>
```

Replace the test identifier with your production AdMob application identifier before release.

## iOS Configuration

1. Add your AdMob application identifier to `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

2. Add the Apple App Tracking Transparency (ATT) description to `ios/Runner/Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier helps us deliver personalized advertisements to you.</string>
```

3. Configure Apple SKAdNetwork identifiers in `ios/Runner/Info.plist` according to Google's official documentation.

## User Consent and Google UMP

AdmobKit collects consent through Google User Messaging Platform (UMP) before it requests any ad, and requests App Tracking Transparency permission on iOS.
Keep `requestConsent: true` (the default) in `AdmobKitConfig`.

1. Configure privacy messages under **Privacy & messaging** in your AdMob dashboard.
2. Publish required European Regulations (GDPR) and US state privacy messages.
3. Provide a privacy settings button in your app settings screen when `isPrivacyOptionsRequired()` returns `true`.
4. Call `AdmobKit.showPrivacyOptionsForm()` when the user taps that button.

## Test Devices and Debug Geography

During development, use official `AdMobTestIds` to prevent account policy penalties.
Do not tap live production advertisements during development or testing.

Configure test devices and simulate European Economic Area (EEA) consent rules:

```dart
AdmobKitConfig consentTestConfiguration(List<String> consentDeviceIds) => AdmobKitConfig(
  consentTestConfig: ConsentTestConfig(
    debugGeography: DebugGeography.debugGeographyEea,
    testIdentifiers: consentDeviceIds,
  ),
);
```

Retrieve test device identifiers from Android logcat or iOS Xcode console logs.
Remove test device identifiers and debug geography configurations before production deployment.

## Build and Verify

Rebuild your app after changing `AndroidManifest.xml` or `Info.plist`, and after adding or upgrading AdmobKit, since it includes native template code:

```sh
flutter clean
flutter run
```

Flutter hot reload does not apply native platform manifest or plist modifications.
If advertisements do not render, read the [Troubleshooting guide](troubleshooting.md).
