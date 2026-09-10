import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../domain/models/ad_placement.dart';
import '../domain/models/ad_placement_state.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/network/connectivity_network_info.dart';
import '../infrastructure/pool/eager_ad_pool.dart';
import 'config/flutter_ads_config.dart';

/// Unified developer-facing facade for the FlutterAds plugin.
///
/// Features a pure "dumb front API":
/// - [initialize]: Boots consent (UMP) & AdMob SDK immediately at app launch.
/// - [registerPlacements]: Primes the eager pool once placements are known (e.g. from Remote Config).
/// - [show]: 0ms non-blocking full-screen display contract.
/// - [isReady], [isLoading], [getState], [watchState]: Transparent placement state queries.
/// - Inline widgets: [AdBannerView], [AdNativeView], [AdPaywallGuard].
abstract final class FlutterAds {
  static EagerAdPool? _pool;
  static ConsentCoordinator? _consent;
  static PlatformAdLogger? _logger;
  static PresentationMutex? _mutex;
  static bool _canRequestAds = false;

  /// Optional driver override for testing environments.
  @visibleForTesting
  static GoogleMobileAdsDriver? driverForTesting;

  /// Sets the internal eager pool for testing purposes.
  @visibleForTesting
  static void setPoolForTesting(EagerAdPool? pool) {
    _pool = pool;
    _canRequestAds = true;
  }

  /// Stage 1: Initializes consent (Google UMP + Apple ATT), initializes Google Mobile Ads SDK,
  /// registers native ad factories, and prepares the internal eager ad pool.
  ///
  /// Can be called immediately at boot (`main()`) before Remote Config or network placements resolve.
  /// If [config.placements] is provided, they are primed immediately.
  static Future<void> initialize({
    FlutterAdsConfig config = const FlutterAdsConfig(),
  }) async {
    _logger = PlatformAdLogger(level: config.logLevel);
    _mutex = PresentationMutex(_logger);
    _consent = ConsentCoordinator(_logger);

    _logger?.info('[FlutterAds] Initializing package...');

    // 1. Consent Flow (Google UMP + Apple ATT)
    if (config.requestConsent) {
      _canRequestAds = await _consent!.gatherConsent(
        testConfig: config.consentTestConfig,
      );
    } else {
      _canRequestAds = true;
    }

    // 2. Initialize Google Mobile Ads SDK
    final driver = driverForTesting ??
        GoogleMobileAdsDriver(
          logger: _logger,
          analytics: config.analytics,
        );

    if (_canRequestAds && config.initializeNativeGma) {
      await driver.initialize(testDeviceIds: config.testDeviceIds);
      try {
        await const MethodChannel('flutter_ads').invokeMethod<dynamic>('registerNativeAdFactories');
      } catch (_) {}
    } else if (!config.initializeNativeGma) {
      _logger?.info('[FlutterAds] Native GMA initialization skipped via config.');
    } else {
      _logger?.warning('[FlutterAds] Consent disallowed ads. Skipping GMA init.');
    }

    // 3. Initialize Eager Pool
    final networkInfo = ConnectivityNetworkInfo();
    _pool = EagerAdPool(
      driver: driver,
      mutex: _mutex!,
      networkInfo: networkInfo,
      timeoutConfig: config.timeouts,
      retryScheduler: config.retryScheduler,
      logger: _logger,
      analytics: config.analytics,
      diagnostics: config.diagnostics,
      isPremium: config.isPremium,
      adTtl: config.adTtl,
    );

    // 4. Prime initial placements if provided at init time
    if (_canRequestAds && config.placements != null && config.placements!.isNotEmpty) {
      _pool!.primeAll(config.placements!);
    }
  }

  /// Stage 2: Registers and primes placements in the eager preloading pool.
  ///
  /// Call this as soon as your ad configuration is ready (e.g. after Firebase Remote Config
  /// or backend API has loaded). Can be called multiple times to register new placements.
  static void registerPlacements(Iterable<AdPlacement> placements) {
    final pool = _pool;
    if (pool == null) {
      _logger?.warning('[FlutterAds] registerPlacements called before initialize().');
      return;
    }

    if (_canRequestAds) {
      pool.primeAll(placements);
    } else {
      _logger?.warning('[FlutterAds] Consent disallowed ads. Skipping placement priming.');
    }
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
    final pool = _pool;
    if (pool == null) {
      _logger?.warning('[FlutterAds] show() called before initialize(). Proceeding.');
      onDismissed?.call();
      return;
    }

    pool.show(
      placement,
      onDismissed: onDismissed,
      onRewardGranted: onRewardGranted,
      onDisplayed: onDisplayed,
    );
  }

  /// Returns true if an ad is primed, fresh, and ready for instant 0ms display.
  static bool isReady(AdPlacement placement) {
    return _pool?.isReady(placement) ?? false;
  }

  /// Returns true if an ad is currently in-flight downloading in the priority queue.
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

  /// Manually requests an on-demand preload for a specific placement.
  static void preload(AdPlacement placement) {
    _pool?.preload(placement);
  }

  /// Returns true if the user is currently entitled to an ad-free experience.
  static bool get isUserPremium => _pool?.isUserPremium ?? false;

  /// Returns true if valid consent has been gathered to request ads.
  static bool get canRequestAds => _canRequestAds;

  /// Presents the Google UMP privacy options form so users can update consent in settings.
  static Future<bool> showPrivacyOptionsForm() async {
    return _consent?.showPrivacyOptionsForm() ?? Future.value(false);
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
  @internal
  static dynamic leaseInlineAd(InlinePlacement placement) {
    return _pool?.leaseInlineAd(placement);
  }

  /// Internal reference to logger.
  @internal
  static PlatformAdLogger? get logger => _logger;

  /// Internal reference to pool.
  @internal
  static EagerAdPool? get pool => _pool;
}
