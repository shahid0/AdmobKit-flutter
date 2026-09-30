import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/infrastructure/appearance/native_appearance.g.dart',
    kotlinOut: 'android/src/main/kotlin/com/example/flutter_ads/NativeAppearance.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.flutter_ads'),
    swiftOut: 'ios/Classes/NativeAppearance.g.swift',
  ),
)
class NativeStyleData {
  NativeStyleData({
    this.background,
    this.headline,
    this.body,
    this.callToActionBackground,
    this.callToActionText,
    this.callToActionCornerRadius,
  });
  int? background;
  int? headline;
  int? body;
  int? callToActionBackground;
  int? callToActionText;
  double? callToActionCornerRadius;
}

/// Complete render manifest, not a delta: omitted renders are released.
@HostApi()
abstract class NativeAppearanceHost {
  void startSession(String sessionId);
  void applyStyle(String sessionId, int revision, Map<String, NativeStyleData> renders);
  void endSession(String sessionId);
}
