import 'dart:async';

import '../domain/contracts/ad_network_info.dart';
import '../domain/models/ad_initialization_state.dart';
import '../domain/models/ad_placement.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/pool/ad_cache_entry.dart';
import '../infrastructure/pool/eager_ad_pool.dart';
import 'config/admob_kit_config.dart';

/// Owns one initialization lifetime. Old async completions cannot revive it.
class AdSession {
  final AdmobKitConfig config;
  final GoogleMobileAdsDriver driver;
  final ConsentCoordinator consent;
  final AdNetworkInfo networkInfo;
  final PlatformAdLogger logger;
  final Future<void> Function() registerNativeFactories;
  final void Function(AdInitializationState) onStateChanged;
  late final PresentationMutex mutex = PresentationMutex(logger);
  late EagerAdPool pool = _createPool();
  final _placements = <String, AdPlacement>{};
  final _capacities = <String, int>{};
  final _disposed = Completer<void>();
  Completer<bool> _settled = Completer<bool>();
  Future<void>? _initialization;
  Future<bool>? _privacyUpdate;
  bool _sdkReady = false;
  AdInitializationState state = AdInitializationState.uninitialized;

  AdSession({
    required this.config,
    required this.driver,
    required this.consent,
    required this.networkInfo,
    required this.logger,
    required this.registerNativeFactories,
    required this.onStateChanged,
  }) {
    _capacities.addAll(config.placementCapacities ?? {});
    for (final placement in config.placements ?? <AdPlacement>[]) {
      _placements[placement.id] = placement;
    }
  }

  bool get isDisposed => _disposed.isCompleted;
  bool get isPremium => config.isPremium?.call() ?? false;
  bool get canRequestAds => state == AdInitializationState.ready && !isDisposed && !isPremium;
  bool get _isResolving => !_settled.isCompleted;

  EagerAdPool _createPool() => EagerAdPool(
    driver: driver,
    mutex: mutex,
    networkInfo: networkInfo,
    timeoutConfig: config.timeouts,
    retryScheduler: config.retryScheduler,
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
      if (config.initializeNativeGma) {
        await driver.initialize(testDeviceIds: config.testDeviceIds);
        if (isDisposed) return;
        await registerNativeFactories();
        if (isDisposed) return;
      }
      _sdkReady = true;
    }
    _setState(AdInitializationState.ready);
    if (isDisposed) return;
    pool.primeAll(_placements.values);
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
      _placements[placement.id] = placement;
    }
    if (capacities != null) {
      _capacities.addAll(capacities);
      for (final entry in capacities.entries) {
        pool.setCapacity(entry.key, entry.value);
      }
    }
    if (canRequestAds) pool.primeAll(added);
  }

  /// Waits for eligibility, then preloads into the current privacy-safe pool.
  Future<void> preload(AdPlacement placement) async {
    while (!isDisposed) {
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return;
      final currentPool = pool;
      await currentPool.preload(placement);
      if (identical(currentPool, pool) && !_isResolving) return;
    }
  }

  /// Waits for eligibility and ad readiness; [timeout] starts after eligibility.
  /// Returns false on denial, failure, timeout, or disposal.
  Future<bool> waitFor(AdPlacement placement, {Duration? timeout}) async {
    while (!isDisposed) {
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return false;
      final currentPool = pool;
      final ready = await currentPool.waitFor(placement, timeout: timeout);
      if (isDisposed) return false;
      if (identical(currentPool, pool) && !_isResolving) return ready && canRequestAds;
    }
    return false;
  }

  /// Waits for eligibility and leases an exclusive inline ad from the current pool.
  /// Discards stale-pool results and returns null when no ad can be leased.
  Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout}) async {
    while (!isDisposed) {
      final allowed = await waitUntilCanRequestAds();
      if (_isResolving) continue;
      if (!allowed || !canRequestAds) return null;
      final currentPool = pool;
      final ad = await currentPool.leaseInlineAd(placement, timeout: timeout);
      if (identical(currentPool, pool) && canRequestAds) return ad;
      await AdCacheEntry.disposeAdInstance(ad);
      if (isDisposed) return null;
    }
    return null;
  }

  /// Presents through the current pool, preserving its splash settlement policy.
  void show(
    FullscreenPlacement placement, {
    void Function()? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    void Function()? onDisplayed,
  }) => pool.show(placement, onDismissed: onDismissed, onRewardGranted: onRewardGranted, onDisplayed: onDisplayed);

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
      pool.dispose();
      pool = _createPool();
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
    pool.dispose();
    if (!_settled.isCompleted) _settled.complete(false);
    onStateChanged(state);
  }
}
