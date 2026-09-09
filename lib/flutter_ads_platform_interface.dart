import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ads_method_channel.dart';

abstract class FlutterAdsPlatform extends PlatformInterface {
  /// Constructs a FlutterAdsPlatform.
  FlutterAdsPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAdsPlatform _instance = MethodChannelFlutterAds();

  /// The default instance of [FlutterAdsPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAds].
  static FlutterAdsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAdsPlatform] when
  /// they register themselves.
  static set instance(FlutterAdsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
