import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads/flutter_ads_platform_interface.dart';
import 'package:flutter_ads/flutter_ads_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAdsPlatform
    with MockPlatformInterfaceMixin
    implements FlutterAdsPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterAdsPlatform initialPlatform = FlutterAdsPlatform.instance;

  test('$MethodChannelFlutterAds is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAds>());
  });

  test('getPlatformVersion', () async {
    FlutterAds flutterAdsPlugin = FlutterAds();
    MockFlutterAdsPlatform fakePlatform = MockFlutterAdsPlatform();
    FlutterAdsPlatform.instance = fakePlatform;

    expect(await flutterAdsPlugin.getPlatformVersion(), '42');
  });
}
