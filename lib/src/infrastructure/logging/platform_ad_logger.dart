import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../domain/contracts/ad_logger.dart';

/// Platform-aware, structured console logger for FlutterAds.
class PlatformAdLogger implements AdLogger {
  final AdLogLevel level;
  final String _tagPrefix;

  PlatformAdLogger({
    AdLogLevel? level,
  })  : level = level ?? (kDebugMode ? AdLogLevel.verbose : AdLogLevel.none),
        _tagPrefix = _resolvePlatformTag();

  static String _resolvePlatformTag() {
    if (kIsWeb) return '[FlutterAds::Web]';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '[FlutterAds::Android]';
      case TargetPlatform.iOS:
        return '[FlutterAds::iOS]';
      case TargetPlatform.macOS:
        return '[FlutterAds::macOS]';
      case TargetPlatform.windows:
        return '[FlutterAds::Windows]';
      case TargetPlatform.linux:
        return '[FlutterAds::Linux]';
      case TargetPlatform.fuchsia:
        return '[FlutterAds::Fuchsia]';
    }
  }

  void _log(AdLogLevel msgLevel, String message, [Object? error, StackTrace? stackTrace]) {
    if (!level.includes(msgLevel)) return;

    final formatted = '$_tagPrefix $message';
    if (error != null) {
      developer.log(
        formatted,
        name: 'FlutterAds',
        level: _toDeveloperLogLevel(msgLevel),
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      debugPrint(formatted);
    }
  }

  int _toDeveloperLogLevel(AdLogLevel level) {
    switch (level) {
      case AdLogLevel.verbose:
        return 500;
      case AdLogLevel.info:
        return 800;
      case AdLogLevel.warning:
        return 900;
      case AdLogLevel.error:
        return 1000;
      case AdLogLevel.none:
        return 0;
    }
  }

  @override
  void debug(String message) => _log(AdLogLevel.verbose, '[Debug] $message');

  @override
  void info(String message) => _log(AdLogLevel.info, '[Info] $message');

  @override
  void warning(String message) => _log(AdLogLevel.warning, '[Warning] $message');

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(AdLogLevel.error, '[Error] $message', error, stackTrace);
}
