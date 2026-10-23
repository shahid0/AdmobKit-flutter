# AdmobKit examples

The example app has two entry points. Both use Google's test app and ad unit IDs.

## Minimal integration

`lib/minimal.dart` shows initialization, registration, a native ad, an adaptive banner, and a transition interstitial, using only the public API. Start here when adding AdmobKit to an app.

```sh
flutter pub get
flutter run -t lib/minimal.dart
```

## Full demo

`lib/main.dart` opens TaskFlow, a sample app with a splash ad, onboarding, tabs with native ads, rewarded ads, a paywall guard, app-open ads, the native template gallery, live styling, and a placement state monitor.

```sh
flutter run
```

The gallery and monitor screens are for inspection; normal apps do not need them.

## Read next

- [Recipes](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/recipes.md) for each flow shown in the demo.
- [Best practices](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/best-practices.md) and [Design decisions](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/design-decisions.md) for how and why.
- [Platform setup](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/setup.md) before using these patterns in your own app.
- [Native ads](https://github.com/shahid0/AdmobKit-flutter/blob/main/doc/native-ads.md#policy-and-production-limits) for text truncation limits to test before release.

Requires Dart 3.11.5 and Flutter 3.41.0 or later, with the Android or iOS development tools.
