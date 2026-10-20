import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/ad_network.dart';
import '../domain/ad_placements.dart';
import '../infrastructure/appearance/native_appearance.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/network/connectivity_network_info.dart';
import '../infrastructure/engine/ad_cache_entry.dart';
import '../infrastructure/engine/ad_engine.dart';
import 'config/admob_kit_config.dart';

AdSession? _activeSession;
PlatformAdLogger? _sessionLogger;
final _sessionInitState = ValueNotifier(AdInitializationState.uninitialized);

@internal
AdSession? get activeAdSession => _activeSession;

@internal
PlatformAdLogger? get adSessionLogger => _sessionLogger;

@internal
ValueListenable<AdInitializationState> get adInitializationStateListenable => _sessionInitState;

/// Ends the current lifetime and notifies retained widget hosts.
@internal
void disposeAdSession() {
  final session = _activeSession;
  _activeSession = null;
  session?.dispose();
  _sessionInitState.value = AdInitializationState.disposed;
}

/// Composes one session. Dependencies apply only to this initialization call.
@internal
Future<void> initializeAdSession({
  required AdmobKitConfig config,
  GoogleMobileAdsDriver? driver,
  AdNetworkInfo? networkInfo,
  bool initializeNativeGma = true,
}) {
  final existing = _activeSession;
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
  _sessionLogger = PlatformAdLogger(level: config.logLevel);
  final appearance = NativeAppearance(defaults: config.nativeStyle);
  late final AdSession session;
  session = AdSession(
    config: config,
    appearance: appearance,
    driver: driver ?? GoogleMobileAdsDriver(logger: _sessionLogger, analytics: config.analytics, appearance: appearance),
    consent: ConsentCoordinator(_sessionLogger),
    networkInfo: networkInfo ?? ConnectivityNetworkInfo(),
    initializeNativeGma: initializeNativeGma,
    logger: _sessionLogger!,
    registerNativeFactories: () async {
      final registered = await const MethodChannel('flutter_ads').invokeMethod<bool>('registerNativeAdFactories');
      if (registered != true) throw StateError('Native ad factory registration failed.');
    },
    onStateChanged: (state) {
      if (identical(_activeSession, session)) _sessionInitState.value = state;
    },
  );
  _activeSession = session;
  return session.initialize();
}

/// Owns one initialization lifetime. Old async completions cannot revive it.
class AdSession {
  final AdmobKitConfig config;
  final bool initializeNativeGma;
  final NativeAppearance? appearance;
  final GoogleMobileAdsDriver driver;
  final ConsentCoordinator consent;
  final AdNetworkInfo networkInfo;
  final PlatformAdLogger logger;
  final Future<void> Function() registerNativeFactories;
  final void Function(AdInitializationState) onStateChanged;
  late final PresentationMutex mutex = PresentationMutex(logger);
  late AdEngine engine = _createEngine();
  final _placements = <String, AdPlacement>{};
  // Consumption belongs to the session, not to its replaceable privacy cache.
  final _consumedLoadOnceIds = <String>{};
  final _capacities = <String, int>{};
  final _disposed = Completer<void>();
  Completer<bool> _settled = Completer<bool>();
  Future<void>? _initialization;
  Future<bool>? _privacyUpdate;
  bool _sdkReady = false;
  AdInitializationState state = AdInitializationState.uninitialized;

  AdSession({
    required this.config,
    this.initializeNativeGma = true,
    this.appearance,
    required this.driver,
    required this.consent,
    required this.networkInfo,
    required this.logger,
    required this.registerNativeFactories,
    required this.onStateChanged,
  }) {
    _capacities.addAll(config.placementCapacities ?? {});
    for (final placement in config.placements ?? <AdPlacement>[]) {
      engine.validatePlacement(placement);
      _placements[placement.id] = placement;
    }
  }

  bool get isDisposed => _disposed.isCompleted;
  bool get isPremium => config.isPremium?.call() ?? false;
  bool get canRequestAds => state == AdInitializationState.ready && !isDisposed && !isPremium;
  bool get _isResolving => !_settled.isCompleted;

  /// Applies initial or live appearance independently of consent/ad requests.
  Future<void> setNativeStyle(NativeAdStyle style, {NativePlacement? placement}) {
    if (isDisposed || appearance == null) return Future.error(StateError('No active native appearance session.'));
    return appearance!.setStyle(style, placement: placement);
  }

  AdEngine _createEngine() => AdEngine(
    consumedLoadOnceIds: _consumedLoadOnceIds,
    driver: driver,
    mutex: mutex,
    networkInfo: networkInfo,
    timeoutConfig: config.timeouts,
    logger: logger,
    analytics: config.analytics,
    diagnostics: config.diagnostics,
    isPremium: () => isPremium,
    canRequestAds: () => canRequestAds,
    adTtl: config.adTtl,
    initialConcurrency: config.initialConcurrency,
    subsequentConcurrency: config.subsequentConcurrency,
    placementCapacities: _capacities,
  );

  void _setState(AdInitializationState value) {
    if (isDisposed || state == value) return;
    state = value;
    logger.info('[Initialization] ${value.name}');
    onStateChanged(value);
  }

  /// Starts one shared initialization pipeline; awaiters receive its failures.
  Future<void> initialize() {
    final existing = _initialization;
    if (existing != null) return existing;
    final completed = Completer<void>();
    _initialization = completed.future;
    // _fail reports failures even when boot is fire-and-forget. Observe errors
    // without replacing the original future returned to awaiting callers.
    completed.future.ignore();
    Future.any<void>([_initialize(), _disposed.future]).then(completed.complete, onError: completed.completeError);
    return completed.future;
  }

  Future<void> _initialize() async {
    try {
      _setState(AdInitializationState.gatheringConsent);
      if (isDisposed) return;
      final allowed = !config.requestConsent || await consent.gatherConsent(testConfig: config.consentTestConfig);
      if (isDisposed) return;
      await _activate(allowed);
    } catch (error, stack) {
      if (isDisposed) return;
      _fail(error, stack);
      rethrow;
    }
  }

  Future<void> _activate(bool allowed) async {
    if (!allowed) {
      _setState(AdInitializationState.consentDenied);
      if (!_settled.isCompleted) _settled.complete(false);
      return;
    }
    if (!_sdkReady) {
      _setState(AdInitializationState.initializingSdk);
      if (isDisposed) return;
      if (initializeNativeGma) {
        await driver.initialize(testDeviceIds: config.testDeviceIds);
        if (isDisposed) return;
        await registerNativeFactories();
        if (isDisposed) return;
      }
      _sdkReady = true;
    }
    _setState(AdInitializationState.ready);
    if (isDisposed) return;
    engine.primeAll(_placements.values);
    if (!_settled.isCompleted) _settled.complete(true);
  }

  void _fail(Object error, StackTrace stack) {
    logger.error('[Initialization] Failed', error, stack);
    _setState(AdInitializationState.failed);
    if (!_settled.isCompleted) _settled.complete(false);
  }

  /// Waits for the current pipeline, including a concurrent privacy update.
  Future<bool> waitUntilCanRequestAds() async {
    while (!isDisposed) {
      final barrier = _settled;
      await barrier.future;
      if (!identical(barrier, _settled)) continue;
      return canRequestAds;
    }
    return false;
  }

  /// Retains placements and capacities, priming them once requests are allowed.
  void registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? capacities}) {
    if (isDisposed) return;
    final added = placements.toList();
    for (final placement in added) {
      engine.validatePlacement(placement);
      _placements[placement.id] = placement;
    }
    if (capacities != null) {
      _capacities.addAll(capacities);
      for (final entry in capacities.entries) {
        engine.setCapacity(entry.key, entry.value);
      }
    }
    if (canRequestAds) engine.primeAll(added);
  }

  /// Checks whether an ad is primed and ready in memory.
  bool isReady(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      engine.isReady(placement, bannerLayout: bannerLayout);

  /// Checks whether [placement] is currently in-flight downloading or queued.
  bool isLoading(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      engine.isLoading(placement, bannerLayout: bannerLayout);

  /// Returns the current lifecycle state of [placement].
  AdPlacementState getState(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      engine.getState(placement, bannerLayout: bannerLayout);

  /// Observes state transitions for [placement].
  Stream<AdPlacementState> watchState(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      engine.watchState(placement, bannerLayout: bannerLayout);

  /// Waits for eligibility, then preloads into the current privacy-safe engine.
  Future<void> preload(AdPlacement placement, {BannerLayout? bannerLayout}) async {
    while (!isDisposed) {
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return;
      final currentEngine = engine;
      await currentEngine.preload(placement, bannerLayout: bannerLayout);
      if (identical(currentEngine, engine) && !_isResolving) return;
    }
  }

  /// Waits for eligibility and ad readiness; [timeout] starts after eligibility.
  /// Returns false on denial, failure, timeout, or disposal.
  Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) async {
    while (!isDisposed) {
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return false;
      final currentEngine = engine;
      final ready = await currentEngine.waitFor(placement, timeout: timeout, bannerLayout: bannerLayout);
      if (isDisposed) return false;
      if (identical(currentEngine, engine) && !_isResolving) return ready && canRequestAds;
    }
    return false;
  }

  /// Waits for eligibility and leases an exclusive inline ad from the current engine.
  Future<dynamic> leaseInlineAd(
    InlinePlacement placement, {
    Duration? timeout,
    BannerLayout? bannerLayout,
    bool Function()? isMounted,
  }) async {
    while (!isDisposed) {
      if (isMounted != null && !isMounted()) return null;
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return null;
      if (isMounted != null && !isMounted()) return null;
      final currentEngine = engine;
      final ad = await currentEngine.leaseInlineAd(
        placement,
        timeout: timeout,
        bannerLayout: bannerLayout,
        isMounted: isMounted,
      );
      if (identical(currentEngine, engine) && canRequestAds) return ad;
      await AdCacheEntry.disposeAdInstance(ad);
      if (isDisposed) return null;
    }
    return null;
  }

  /// Presents through the current engine, preserving its splash settlement policy.
  void show(
    FullscreenPlacement placement, {
    void Function()? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    void Function()? onDisplayed,
  }) => engine.show(placement, onDismissed: onDismissed, onRewardGranted: onRewardGranted, onDisplayed: onDisplayed);

  /// Reads the current settled UMP requirement, including concurrent updates.
  Future<bool> isPrivacyOptionsRequired() async {
    while (!isDisposed) {
      final barrier = _settled;
      await barrier.future;
      if (!identical(barrier, _settled)) continue;
      if (isDisposed) return false;
      final bool required;
      try {
        required = await Future.any<bool>([consent.isPrivacyOptionsRequired(), _disposed.future.then((_) => false)]);
      } catch (_) {
        if (isDisposed) return false;
        if (!identical(barrier, _settled)) continue;
        rethrow;
      }
      if (isDisposed) return false;
      if (identical(barrier, _settled)) return required;
    }
    return false;
  }

  /// Coalesces privacy updates and re-resolves eligibility before allowing ads.
  Future<bool> showPrivacyOptionsForm() {
    final existing = _privacyUpdate;
    if (existing != null) return existing;
    final completed = Completer<bool>();
    _privacyUpdate = completed.future;
    Future.any<bool>([
      _updatePrivacy(),
      _disposed.future.then((_) => false),
    ]).then(completed.complete, onError: completed.completeError);
    return completed.future;
  }

  Future<bool> _updatePrivacy() async {
    try {
      if (!_settled.isCompleted) await _settled.future;
      if (isDisposed) return false;
      if (mutex.isLocked) {
        logger.warning('[Consent] Cannot present privacy options over a fullscreen ad.');
        return false;
      }
      _settled = Completer<bool>();
      _setState(AdInitializationState.updatingConsent);
      if (isDisposed) return false;
      engine.dispose();
      engine = _createEngine();
      final shown = await consent.showPrivacyOptionsForm();
      if (isDisposed) return false;
      final allowed = await consent.canRequestAds();
      if (isDisposed) return false;
      await _activate(allowed);
      return shown;
    } catch (error, stack) {
      if (!isDisposed) _fail(error, stack);
      return false;
    } finally {
      _privacyUpdate = null;
    }
  }

  /// Closes this lifetime and settles pending readiness waits as unavailable.
  void dispose() {
    if (isDisposed) return;
    _disposed.complete();
    state = AdInitializationState.disposed;
    consent.dispose();
    engine.dispose();
    mutex.dispose();
    if (!_settled.isCompleted) _settled.complete(false);
    unawaited(
      appearance?.dispose().catchError((Object error, StackTrace stack) {
        logger.error('[Native] Appearance disposal failed', error, stack);
      }),
    );
    onStateChanged(state);
  }
}
