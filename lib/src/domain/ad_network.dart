import 'package:flutter/foundation.dart';
import 'ad_placements.dart';

/// Normalized network types for ad request optimization and telemetry.
enum AdNetworkType {
  /// Local wireless 802.11 network.
  wifi,

  /// Cellular mobile data network (4G, 5G, LTE, 3G, EDGE).
  cellular,

  /// Wired Ethernet connection.
  ethernet,

  /// No active network connectivity detected.
  none,

  /// Network state is unknown or indeterminate.
  unknown;

  /// Whether the device currently has an active, potentially reachable network.
  bool get isConnected => this != AdNetworkType.none;

  /// Whether the device is on a cellular or metered connection.
  bool get isCellular => this == AdNetworkType.cellular;
}

/// Abstract contract for reading and observing network connectivity conditions.
abstract interface class AdNetworkInfo {
  /// Returns the current active network type.
  Future<AdNetworkType> getNetworkType();

  /// The stream of network type transitions.
  Stream<AdNetworkType> get onNetworkTypeChanged;
}

/// Network-specific timeout policy.
@immutable
class AdTimeoutPolicy {
  final Duration wifiTimeout;
  final Duration cellularTimeout;
  final Duration ethernetTimeout;
  final Duration otherTimeout;

  const AdTimeoutPolicy({
    this.wifiTimeout = const Duration(seconds: 25),
    this.cellularTimeout = const Duration(seconds: 45),
    this.ethernetTimeout = const Duration(seconds: 20),
    this.otherTimeout = const Duration(seconds: 35),
  });

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
  final AdTimeoutPolicy fullscreen;
  final AdTimeoutPolicy inline;
  final AdTimeoutPolicy splash;

  const AdTimeoutConfig({
    this.fullscreen = const AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 30),
      cellularTimeout: Duration(seconds: 50),
      ethernetTimeout: Duration(seconds: 20),
      otherTimeout: Duration(seconds: 40),
    ),
    this.inline = const AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 20),
      cellularTimeout: Duration(seconds: 35),
      ethernetTimeout: Duration(seconds: 15),
      otherTimeout: Duration(seconds: 25),
    ),
    this.splash = const AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 25),
      cellularTimeout: Duration(seconds: 45),
      ethernetTimeout: Duration(seconds: 20),
      otherTimeout: Duration(seconds: 35),
    ),
  });

  /// Standard network timeout profile calibrated for resilient global delivery,
  /// accommodating high-latency mobile networks out of the box.
  static const standard = AdTimeoutConfig();

  /// High-tolerance profile specifically calibrated for regions with constrained,
  /// high-latency, or 2G/3G/spotty 4G connectivity (e.g. Ethiopia, Pakistan, and emerging markets).
  static const emergingMarkets = AdTimeoutConfig(
    fullscreen: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 45),
      cellularTimeout: Duration(seconds: 75),
      ethernetTimeout: Duration(seconds: 30),
      otherTimeout: Duration(seconds: 60),
    ),
    inline: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 30),
      cellularTimeout: Duration(seconds: 50),
      ethernetTimeout: Duration(seconds: 20),
      otherTimeout: Duration(seconds: 40),
    ),
    splash: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 35),
      cellularTimeout: Duration(seconds: 65),
      ethernetTimeout: Duration(seconds: 25),
      otherTimeout: Duration(seconds: 50),
    ),
  );

  /// Aggressive profile with tighter boundaries for low-latency Tier-1 environments.
  static const aggressive = AdTimeoutConfig(
    fullscreen: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 15),
      cellularTimeout: Duration(seconds: 25),
      ethernetTimeout: Duration(seconds: 10),
      otherTimeout: Duration(seconds: 20),
    ),
    inline: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 10),
      cellularTimeout: Duration(seconds: 15),
      ethernetTimeout: Duration(seconds: 8),
      otherTimeout: Duration(seconds: 12),
    ),
    splash: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 15),
      cellularTimeout: Duration(seconds: 25),
      ethernetTimeout: Duration(seconds: 12),
      otherTimeout: Duration(seconds: 20),
    ),
  );

  /// Relaxed profile allowing generous download windows for rich media assets.
  static const relaxed = AdTimeoutConfig(
    fullscreen: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 35),
      cellularTimeout: Duration(seconds: 60),
      ethernetTimeout: Duration(seconds: 25),
      otherTimeout: Duration(seconds: 45),
    ),
    inline: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 25),
      cellularTimeout: Duration(seconds: 40),
      ethernetTimeout: Duration(seconds: 15),
      otherTimeout: Duration(seconds: 30),
    ),
    splash: AdTimeoutPolicy(
      wifiTimeout: Duration(seconds: 30),
      cellularTimeout: Duration(seconds: 50),
      ethernetTimeout: Duration(seconds: 20),
      otherTimeout: Duration(seconds: 40),
    ),
  );

  Duration resolve({
    required AdFormat format,
    required AdNetworkType network,
    bool isSplash = false,
  }) {
    if (isSplash) return splash.resolve(network);
    return format.isFullscreen
        ? fullscreen.resolve(network)
        : inline.resolve(network);
  }
}
