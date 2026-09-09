import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../domain/models/ad_placement.dart';
import '../infrastructure/consent/consent_coordinator.dart';
import '../infrastructure/drivers/google_mobile_ads_driver.dart';
import '../infrastructure/logging/platform_ad_logger.dart';
import '../infrastructure/mutex/presentation_mutex.dart';
import '../infrastructure/network/connectivity_network_info.dart';
import '../infrastructure/pool/eager_ad_pool.dart';
import 'config/flutter_ads_config.dart';
import 'lifecycle/app_resume_ad_listener.dart';
import 'lifecycle/flutter_ads_route_observer.dart';

/// Unified developer-facing facade for the FlutterAds plugin.
///
/// Provides a zero-boilerplate "dumb front API" where 95% of use-cases require only:
/// - [initialize]
/// - [show]
/// - Inline widgets ([AdBannerView], [AdNativeView], [AdPaywallGuard])
abstract final class FlutterAds {
  /// Global route observer tracking active screens for lifecycle-aware ad triggers.
  static final FlutterAdsRouteObserver routeObserver = FlutterAdsRouteObserver();

  static EagerAdPool? _pool;
  static ConsentCoordinator? _consent;
  static PlatformAdLogger? _logger;
  static PresentationMutex? _mutex;
  static AppResumeAdListener? _resumeListener;
  static bool _canRequestAds = false;

  /// Initializes the FlutterAds SDK, executes consent (if enabled),
  /// initializes Google Mobile Ads, and primes the startup priority queue.
  static Future<void> initialize({
    required FlutterAdsConfig config,
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
    final driver = GoogleMobileAdsDriver(
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

    // 4. Attach App Resume Listener if any AppOpenPlacement is registered
    final appOpenPlacement = config.placements.whereType<AppOpenPlacement>().firstOrNull;
    if (appOpenPlacement != null) {
      _resumeListener = AppResumeAdListener(
        placement: appOpenPlacement,
        pool: _pool!,
        logger: _logger,
        routeObserver: routeObserver,
      );
      _resumeListener!.attach();
    }

    // 5. Prime startup placements
    if (_canRequestAds) {
      _pool!.primeAll(config.placements);
    }
  }

  /// Displays a full-screen ad (Interstitial, Rewarded, or App Open) with a 0ms Non-Blocking contract.
  ///
  /// - If the ad is ready in memory: displays immediately.
  /// - If unready or offline: invokes [onDismissed] immediately without blocking user navigation.
  /// - Passing an inline placement (Banner/Native) is prevented at compile time.
  static void show(
    FullscreenPlacement placement, {
    required VoidCallback onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) {
    final pool = _pool;
    if (pool == null) {
      _logger?.warning('[FlutterAds] show() called before initialize(). Proceeding.');
      onDismissed();
      return;
    }

    pool.show(
      placement,
      onDismissed: onDismissed,
      onRewardGranted: onRewardGranted,
      onDisplayed: onDisplayed,
    );
  }

  /// Returns true if an ad is primed, fresh, and ready for 0ms display.
  static bool isReady(AdPlacement placement) {
    return _pool?.isReady(placement) ?? false;
  }

  /// Returns true if the user is currently entitled to an ad-free experience.
  static bool get isUserPremium => _pool?.isUserPremium ?? false;

  /// Pauses automatic presentation of App Open ads on resume
  /// (e.g. while camera/gallery picker is active, or during sensitive user flows).
  static void pauseAppOpen() {
    _resumeListener?.pause();
  }

  /// Resumes automatic presentation of App Open ads on resume.
  static void resumeAppOpen() {
    _resumeListener?.resume();
  }

  /// Internal map tracking action counts for interval-based ad triggers.
  static final Map<String, int> _actionCounters = {};

  /// Increments an action counter for [actionKey] and returns `true` if it reaches [interval].
  ///
  /// Resets the counter to 0 upon reaching the threshold.
  /// Example:
  /// ```dart
  /// if (FlutterAds.recordActionAndCheckInterval('task_completed', interval: 3)) {
  ///   FlutterAds.show(SampleAds.interstitial, onDismissed: () {});
  /// }
  /// ```
  static bool recordActionAndCheckInterval(String actionKey, {int interval = 3}) {
    if (isUserPremium) return false;
    final current = (_actionCounters[actionKey] ?? 0) + 1;
    if (current >= interval) {
      _actionCounters[actionKey] = 0;
      return true;
    }
    _actionCounters[actionKey] = current;
    return false;
  }

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
