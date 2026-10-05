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

/// Actual host width and scaled typography. Null height requests inline sizing.
class NativeLayoutRequest {
  NativeLayoutRequest({
    required this.width,
    this.height,
    required this.headlineSize,
    required this.bodySize,
    required this.metadataSize,
    required this.actionSize,
  });
  double width;
  double? height;
  double headlineSize;
  double bodySize;
  double metadataSize;
  double actionSize;
}

/// Complete render manifest, not a delta: omitted renders are released.
@HostApi()
abstract class NativeAppearanceHost {
  void startSession(String sessionId);
  void applyStyle(String sessionId, int revision, Map<String, NativeStyleData> renders);
  void endSession(String sessionId);
  double layoutNativeAd(String sessionId, String renderId, NativeLayoutRequest request);
}
