import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/contracts/ad_network_info.dart';
import '../domain/models/ad_initialization_state.dart';
import '../infrastructure/appearance/native_appearance.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/network/connectivity_network_info.dart';
import 'ad_session.dart';
import 'config/admob_kit_config.dart';

// Owns the single app session. This library is not exported by the package.
AdSession? _session;
PlatformAdLogger? _logger;
final _initializationState = ValueNotifier(AdInitializationState.uninitialized);

@internal
AdSession? get activeAdSession => _session;

@internal
PlatformAdLogger? get adSessionLogger => _logger;

@internal
ValueListenable<AdInitializationState> get adInitializationStateListenable => _initializationState;

/// Ends the current lifetime and notifies retained widget hosts.
@internal
void disposeAdSession() {
  final session = _session;
  _session = null;
  session?.dispose();
  _initializationState.value = AdInitializationState.disposed;
}

/// Composes one session. Dependencies apply only to this initialization call.
@internal
Future<void> initializeAdSession({
  required AdmobKitConfig config,
  GoogleMobileAdsDriver? driver,
  AdNetworkInfo? networkInfo,
  bool initializeNativeGma = true,
}) {
  final existing = _session;
  if (existing != null && existing.state != AdInitializationState.failed && !existing.isDisposed) {
    return existing.initialize();
  }
  if (config.initialConcurrency < 1 || config.subsequentConcurrency < 1) {
    throw ArgumentError('Ad request concurrency must be positive.');
  }
  if (config.adTtl <= Duration.zero) throw ArgumentError('Ad freshness TTL must be positive.');
  for (final policy in [config.timeouts.fullscreen, config.timeouts.inline, config.timeouts.splash]) {
    if ([
      policy.wifiTimeout,
      policy.cellularTimeout,
      policy.ethernetTimeout,
      policy.otherTimeout,
    ].any((timeout) => timeout <= Duration.zero)) {
      throw ArgumentError('Ad request timeouts must be positive.');
    }
  }
  disposeAdSession();
  _logger = PlatformAdLogger(level: config.logLevel);
  final appearance = NativeAppearance(defaults: config.nativeStyle);
  late final AdSession session;
  session = AdSession(
    config: config,
    appearance: appearance,
    driver: driver ?? GoogleMobileAdsDriver(logger: _logger, analytics: config.analytics, appearance: appearance),
    consent: ConsentCoordinator(_logger),
    networkInfo: networkInfo ?? ConnectivityNetworkInfo(),
    initializeNativeGma: initializeNativeGma,
    logger: _logger!,
    registerNativeFactories: () async {
      final registered = await const MethodChannel('flutter_ads').invokeMethod<bool>('registerNativeAdFactories');
      if (registered != true) throw StateError('Native ad factory registration failed.');
    },
    onStateChanged: (state) {
      if (identical(_session, session)) _initializationState.value = state;
    },
  );
  _session = session;
  return session.initialize();
}
