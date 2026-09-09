import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/contracts/ad_network_info.dart';

/// Implementation of [AdNetworkInfo] backed by `connectivity_plus`.
class ConnectivityNetworkInfo implements AdNetworkInfo {
  final Connectivity _connectivity;

  ConnectivityNetworkInfo([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  @override
  Future<AdNetworkType> getNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _mapResultsToNetworkType(results);
    } catch (_) {
      return AdNetworkType.unknown;
    }
  }

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged {
    return _connectivity.onConnectivityChanged.map(_mapResultsToNetworkType);
  }

  static AdNetworkType _mapResultsToNetworkType(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return AdNetworkType.none;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      return AdNetworkType.wifi;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return AdNetworkType.ethernet;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return AdNetworkType.cellular;
    }
    return AdNetworkType.unknown;
  }
}
