import 'package:flutter/foundation.dart';
import '../contracts/ad_network_info.dart';
import 'ad_format.dart';

/// Network-specific timeout policy.
@immutable
class AdTimeoutPolicy {
  final Duration wifiTimeout;
  final Duration cellularTimeout;
  final Duration ethernetTimeout;
  final Duration otherTimeout;

  const AdTimeoutPolicy({
    this.wifiTimeout = const Duration(seconds: 12),
    this.cellularTimeout = const Duration(seconds: 22),
    this.ethernetTimeout = const Duration(seconds: 10),
    this.otherTimeout = const Duration(seconds: 18),
  });

  /// Resolves the timeout duration for the given network type.
  Duration resolve(AdNetworkType network) {
    switch (network) {
      case AdNetworkType.wifi:
        return wifiTimeout;
      case AdNetworkType.cellular:
        return cellularTimeout;
      case AdNetworkType.ethernet:
        return ethernetTimeout;
      case AdNetworkType.none:
      case AdNetworkType.unknown:
        return otherTimeout;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdTimeoutPolicy &&
          runtimeType == other.runtimeType &&
          wifiTimeout == other.wifiTimeout &&
          cellularTimeout == other.cellularTimeout &&
          ethernetTimeout == other.ethernetTimeout &&
          otherTimeout == other.otherTimeout;

  @override
  int get hashCode =>
      wifiTimeout.hashCode ^
      cellularTimeout.hashCode ^
      ethernetTimeout.hashCode ^
      otherTimeout.hashCode;
}

/// Adaptive timeout configuration separating fullscreen and inline ad formats.
@immutable
class AdTimeoutConfig {
  /// Timeout policy applied to fullscreen formats (Interstitial, Rewarded, AppOpen).
  final AdTimeoutPolicy fullscreen;

  /// Timeout policy applied to inline formats (Banner, Native).
  final AdTimeoutPolicy inline;

  const AdTimeoutConfig({
    this.fullscreen = const AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 15),
      cellularTimeout: Duration(seconds: 25),
      ethernetTimeout: Duration(seconds: 12),
      otherTimeout: Duration(seconds: 20),
    ),
    this.inline = const AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 10),
      cellularTimeout: Duration(seconds: 15),
      ethernetTimeout: Duration(seconds: 8),
      otherTimeout: Duration(seconds: 12),
    ),
  });

  /// Standard profile balancing fast cancellation with network tolerance.
  static const standard = AdTimeoutConfig();

  /// Aggressive profile with shorter bounds for ultra-responsive fallbacks.
  static const aggressive = AdTimeoutConfig(
    fullscreen: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 10),
      cellularTimeout: Duration(seconds: 18),
      ethernetTimeout: Duration(seconds: 8),
      otherTimeout: Duration(seconds: 15),
    ),
    inline: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 6),
      cellularTimeout: Duration(seconds: 10),
      ethernetTimeout: Duration(seconds: 5),
      otherTimeout: Duration(seconds: 8),
    ),
  );

  /// Relaxed profile with higher bounds for extremely spotty 2G/3G connections.
  static const relaxed = AdTimeoutConfig(
    fullscreen: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 20),
      cellularTimeout: Duration(seconds: 35),
      ethernetTimeout: Duration(seconds: 15),
      otherTimeout: Duration(seconds: 25),
    ),
    inline: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 15),
      cellularTimeout: Duration(seconds: 20),
      ethernetTimeout: Duration(seconds: 10),
      otherTimeout: Duration(seconds: 15),
    ),
  );

  /// Resolves the timeout for a given format and network condition.
  Duration resolve({
    required AdFormat format,
    required AdNetworkType network,
  }) {
    return format.isFullscreen
        ? fullscreen.resolve(network)
        : inline.resolve(network);
  }
}
