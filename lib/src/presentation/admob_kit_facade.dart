import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../domain/contracts/ad_network_info.dart';
import '../domain/models/ad_placement.dart';
import '../domain/models/ad_placement_state.dart';
import '../domain/models/ad_initialization_state.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/network/connectivity_network_info.dart';
import '../infrastructure/pool/eager_ad_pool.dart';
import 'config/admob_kit_config.dart';
import 'ad_session.dart';

/// Unified developer-facing facade for the AdmobKit plugin.
///
/// Features a pure 0ms non-blocking API:
/// - [initialize]: Boots consent (UMP) & AdMob SDK immediately at app launch.
/// - [registerPlacements]: Primes the eager pool once placements are known (e.g. from Remote Config).
/// - [show]: 0ms non-blocking full-screen display contract.
/// - [isReady], [isLoading], [getState], [watchState]: Transparent placement state queries.
/// - [waitFor]: Deterministic splash settlement without blind timers.
/// - Inline widgets: `AdBannerView`, `AdNativeView`, `AdPaywallGuard`.
abstract final class AdmobKit {
  static AdSession? _session;
  static EagerAdPool? _testPool;
  static EagerAdPool? get _pool => _testPool ?? _session?.pool;
  static PlatformAdLogger? _logger;
  static final _initializationState = ValueNotifier(AdInitializationState.uninitialized);

  /// Current consent/SDK stage. This is separate from individual ad readiness.
  static AdInitializationState get initializationState => _initializationState.value;

  /// Observable stage, suitable for ValueListenableBuilder without polling.
  static ValueListenable<AdInitializationState> get initializationStateListenable => _initializationState;

  /// Optional driver override for testing environments.
  @visibleForTesting
  static GoogleMobileAdsDriver? driverForTesting;

  /// Optional network info override for testing environments.
  @visibleForTesting
  static AdNetworkInfo? networkInfoForTesting;

  /// Sets the internal eager pool for testing purposes.
  @visibleForTesting
  static void setPoolForTesting(EagerAdPool? pool) {
    dispose();
    _testPool = pool;
    _initializationState.value = pool == null ? AdInitializationState.disposed : AdInitializationState.ready;
  }

  /// Disposes the eager ad pool and releases all locks and resources.
  static void dispose() {
    final session = _session;
    final testPool = _testPool;
    _session = null;
    _testPool = null;
    session?.dispose();
    testPool?.dispose();
    _initializationState.value = AdInitializationState.disposed;
  }

  /// Initializes consent (Google UMP + Apple ATT), native Google Mobile Ads SDK,
  /// registers native ad factories, and prepares the internal eager ad pool.
  ///
  /// Can be called immediately at boot (`main()`) before Remote Config or network placements resolve.
  /// If [AdmobKitConfig.placements] is provided, they are primed immediately.
  /// Concurrent/repeated calls share the first initialization and configuration.
  /// Dispose before replacing configuration. Failed initialization can be retried.
  /// Errors are logged and retained for awaiters, even if the future is initially ignored.
  /// Disposal releases the future without starting ads.
  static Future<void> initialize({AdmobKitConfig config = const AdmobKitConfig()}) {
    final existing = _session;
    if (existing != null && existing.state != AdInitializationState.failed && !existing.isDisposed) {
      return existing.initialize();
    }
    dispose();
    _logger = PlatformAdLogger(level: config.logLevel);
    late final AdSession session;
    session = AdSession(
      config: config,
      driver: driverForTesting ?? GoogleMobileAdsDriver(logger: _logger, analytics: config.analytics),
      consent: ConsentCoordinator(_logger),
      networkInfo: networkInfoForTesting ?? ConnectivityNetworkInfo(),
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

  /// Stage 2: Registers and primes placements in the eager preloading pool.
  ///
  /// Call this as soon as your ad configuration is ready (e.g. after Firebase Remote Config
  /// or backend API has loaded). Can be called multiple times to register new placements.
  static void registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? placementCapacities}) {
    final session = _session;
    if (session == null) {
      _logger?.warning('[AdmobKit] registerPlacements called before initialize().');
      return;
    }
    session.registerPlacements(placements, capacities: placementCapacities);
  }

  /// Displays a full-screen ad (Interstitial, Rewarded, or App Open) with a 0ms Non-Blocking contract.
  ///
  /// - If the ad is ready in memory: displays immediately.
  /// - If unready or offline: invokes [onDismissed] immediately without blocking user navigation.
  /// - Passing an inline placement (Banner/Native) is prevented at compile time.
  static void show(
    FullscreenPlacement placement, {
    VoidCallback? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) {
    final session = _session;
    if (session != null) {
      session.show(placement, onDismissed: onDismissed, onRewardGranted: onRewardGranted, onDisplayed: onDisplayed);
      return;
    }
    final pool = _testPool;
    if (pool == null) {
      _logger?.warning('[AdmobKit] show() called before initialize(). Proceeding.');
      onDismissed?.call();
      return;
    }

    pool.show(placement, onDismissed: onDismissed, onRewardGranted: onRewardGranted, onDisplayed: onDisplayed);
  }

  /// Whether an ad is primed, fresh, and ready for instant 0ms display.
  static bool isReady(AdPlacement placement) {
    return _pool?.isReady(placement) ?? false;
  }

  /// Whether an ad is currently in-flight downloading in the priority queue.
  static bool isLoading(AdPlacement placement) {
    return _pool?.isLoading(placement) ?? false;
  }

  /// Returns the current lifecycle state of [placement].
  static AdPlacementState getState(AdPlacement placement) {
    return _pool?.getState(placement) ?? AdPlacementState.unloaded;
  }

  /// Observes state transitions for [placement] (e.g. for reactive splash waiting).
  static Stream<AdPlacementState> watchState(AdPlacement placement) {
    return _pool?.watchState(placement) ?? const Stream.empty();
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  ///
  /// Returns `true` if the ad is ready in memory; `false` if failed, timed out, or user is premium.
  /// Waits for pending initialization/privacy resolution before loading. [timeout]
  /// applies to the ad wait, not to time spent resolving consent or the SDK.
  static Future<bool> waitFor(AdPlacement placement, {Duration? timeout}) {
    return _session?.waitFor(placement, timeout: timeout) ??
        _testPool?.waitFor(placement, timeout: timeout) ??
        Future.value(false);
  }

  /// Manually requests an on-demand preload for a specific placement.
  static void preload(AdPlacement placement) {
    if (_session != null) {
      unawaited(_session!.preload(placement));
    } else {
      _testPool?.preload(placement);
    }
  }

  /// Whether the user is currently entitled to an ad-free experience.
  static bool get isUserPremium => _session?.isPremium ?? _testPool?.isUserPremium ?? false;

  /// Whether a full-screen ad is currently active on screen.
  static bool get isShowingAd => _pool?.mutex.isLocked ?? false;

  /// Snapshot: consent AND SDK/factories are ready and the user is not premium.
  /// False can mean still resolving. Await [waitUntilCanRequestAds] for a decision.
  static bool get canRequestAds => _session?.canRequestAds ?? (_testPool != null && !_testPool!.isUserPremium);

  /// Waits for consent, ATT, SDK initialization and native factory registration.
  /// Returns false only for a settled denial/failure, premium, disposal, or when
  /// initialize has not been called. Does not start initialization implicitly.
  static Future<bool> waitUntilCanRequestAds() => _session?.waitUntilCanRequestAds() ?? Future.value(canRequestAds);

  /// Presents the Google UMP privacy options form so users can update consent in settings.
  static Future<bool> showPrivacyOptionsForm() async {
    return _session?.showPrivacyOptionsForm() ?? Future.value(false);
  }

  /// Opens the native Google Mobile Ads Inspector for on-device ad verification.
  static void openAdInspector([void Function(String? error)? onComplete]) {
    try {
      MobileAds.instance.openAdInspector((adError) {
        onComplete?.call(adError?.message);
      });
    } catch (e) {
      onComplete?.call(e.toString());
    }
  }

  /// Leases an inline ad from the pool buffer. Internal package use.
  ///
  /// Resolves with an exclusively-owned ad instance (buffered immediately or
  /// delivered on replenishment), or `null` on timeout / premium / failure.
  @internal
  static Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout}) {
    return _session?.leaseInlineAd(placement, timeout: timeout) ??
        _testPool?.leaseInlineAd(placement, timeout: timeout) ??
        Future<dynamic>.value(null);
  }

  /// Internal reference to logger.
  @internal
  static PlatformAdLogger? get logger => _logger;

  /// Internal reference to pool.
  @internal
  static EagerAdPool? get pool => _pool;
}

// NOTE: The legacy `typedef FlutterAds = AdmobKit;` alias was removed.
// Use [AdmobKit] everywhere. If you still reference `FlutterAds` from an
// older integration, do a one-line find/replace to `AdmobKit` (same API,
// same members) and update the import to
// `package:admob_kit_flutter/admob_kit_flutter.dart`.
