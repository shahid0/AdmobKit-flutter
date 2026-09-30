import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/infrastructure/appearance/native_appearance.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/example/flutter_ads/NativeAppearance.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.flutter_ads'),
    swiftOut: 'ios/Classes/NativeAppearance.g.swift',
  ),
)
class NativePalette {
  NativePalette({this.background, this.headline, this.body, this.callToActionBackground, this.callToActionText});
  int? background;
  int? headline;
  int? body;
  int? callToActionBackground;
  int? callToActionText;
}

/// Complete render manifest, not a delta: omitted renders are released.
@HostApi()
abstract class NativeAppearanceHost {
  void startSession(String sessionId);
  void applyColors(String sessionId, int revision, Map<String, NativePalette> renders);
  void endSession(String sessionId);
}
