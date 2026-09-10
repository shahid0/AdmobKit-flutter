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

