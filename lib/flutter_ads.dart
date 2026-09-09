
import 'flutter_ads_platform_interface.dart';

class FlutterAds {
  Future<String?> getPlatformVersion() {
    return FlutterAdsPlatform.instance.getPlatformVersion();
  }
}
