# Android and iOS setup

AdmobKit supports Android and iOS. This package requires Dart 3.11.5 and Flutter 3.41.0 or later.
An AdMob app ID is different from an ad unit ID.
The app ID contains `~`. Ad unit IDs normally contain `/`.

## Android

Add your AdMob app ID inside `application` in `android/app/src/main/AndroidManifest.xml`.
This example uses Google's test app ID.

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713" />
```

## iOS

Add your app ID to `ios/Runner/Info.plist`. This example uses Google's test app ID.

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
```

These settings are required by the [Google Mobile Ads Flutter setup guide](https://developers.google.com/admob/flutter/quick-start).
Follow Google's current linked iOS instructions for applicable attribution configuration.
Do not copy an incomplete or outdated SKAdNetwork list from an example.

The package can request ATT on iOS. Supply a truthful, localized purpose string in your app:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>We use this permission to provide personalized advertising.</string>
```

Adjust this string to match the actual app behavior. ATT and UMP are different permission systems.
Complete the app's privacy declarations and platform requirements before production use.

## Consent and privacy messages

Keep `requestConsent: true`, the default, for package-managed consent.
Configure the applicable privacy messages under Privacy & messaging in your AdMob account.
The package gathers consent before eligible ad requests. Do not add a second consent-loading controller.

Show a privacy options entry point when `isPrivacyOptionsRequired()` returns true.
Use `showPrivacyOptionsForm()` from that control. Follow the [privacy settings recipe](recipes.md#privacy-settings).
The SDK determines whether the entry point is required. See [Google's UMP guide](https://developers.google.com/admob/flutter/privacy).
An integration with consent collection is not, by itself, a legal compliance guarantee.

`requestConsent: false` skips package UMP and ATT collection.
Do not use it as a production shortcut to make missing ads appear.
The app must deliberately own any required collection outside this package.

## Test ads and consent

Use `AdMobTestIds` for development ad units. Production unit IDs are platform- and format-specific.
Use `testDeviceIds` for AdMob test devices and `ConsentTestConfig` for UMP test devices.
The identifiers can differ. Use the identifiers printed by the respective SDK.
Debug geography applies only to configured test devices.
For consent testing, use your own AdMob app ID with a configured privacy message.
You can still use test ad unit IDs. A sample app ID does not represent your account's privacy-message configuration.

```dart
AdmobKitConfig consentTestConfiguration(List<String> consentDeviceIds) => AdmobKitConfig(
  consentTestConfig: ConsentTestConfig(
    debugGeography: DebugGeography.debugGeographyEea,
    testIdentifiers: consentDeviceIds,
  ),
);
```

`DebugGeography` is available through the supported package import.
Use `debugGeographyDisabled` outside forced-geography testing.
Remove forced geography and test-device configuration before production release.
Do not click live production ads during testing.

## Run and verify

From `example`, run the small integration app with `flutter run -t lib/minimal.dart`.
Run `flutter run` for the diagnostic gallery.
After native plugin changes, rebuild the app; hot reload does not rebuild Android or iOS code.
Use [Troubleshooting](troubleshooting.md) if an ad does not appear.
