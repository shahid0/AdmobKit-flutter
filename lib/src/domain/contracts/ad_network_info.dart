/// Normalized network types for ad request optimization and telemetry.
enum AdNetworkType {
  wifi,
  cellular,
  ethernet,
  none,
  unknown;

  /// Returns true if the device currently has an active, potentially reachable network.
  bool get isConnected => this != AdNetworkType.none;

  /// Returns true if the device is on a cellular/metered connection.
  bool get isCellular => this == AdNetworkType.cellular;
}

/// Abstract contract for reading and observing network connectivity conditions.
abstract interface class AdNetworkInfo {
  /// Returns the current active network type.
  Future<AdNetworkType> getNetworkType();

  /// Stream of network type transitions.
  Stream<AdNetworkType> get onNetworkTypeChanged;
}
