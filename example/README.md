# Example apps

The example directory has two entry points.

## Minimal integration

`lib/minimal.dart` shows initialization, registration, native content, an adaptive banner, and a normal transition.
It uses only the supported public package import. Start here when adding AdmobKit to an app.

```sh
flutter pub get
flutter run -t lib/minimal.dart
```

## Gallery and diagnostics

`lib/main.dart` opens TaskFlow Pro, including the native template gallery, style controls, and diagnostic screens.
It uses Google's test app and ad unit IDs.

```sh
flutter run
```

The gallery is for inspection and testing. Its diagnostic controls are not required for normal app integration.
Neither example guarantees production fill, zero layout shifts, or policy compliance.

Read the [public guides](../README.md#choose-a-guide) for supported use.
The [native production limit](../docs/native-ads.md#production-limit) remains unresolved.

## Requirements

Use Dart 3.11.5 and Flutter 3.41.0 or later, plus the Android or iOS development tools.
Complete [platform setup](../docs/setup.md) when using these examples in another app.
