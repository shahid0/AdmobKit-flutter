import 'dart:async';
import '../domain/models/native_ad_style.dart';
import '../infrastructure/appearance/native_appearance.dart';
import '../domain/models/banner_layout.dart';
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
import '../infrastructure/mutex/presentation_mutex.dart';
import 'config/admob_kit_config.dart';
import 'ad_session.dart';

/// Unified developer-facing facade for the AdmobKit plugin.
///
/// [initialize] resolves consent and SDK/factory readiness. Register reachable
/// placements with [registerPlacements], and use [waitFor] for ad readiness.
/// [show] presents cached fullscreen ads; splash placements may settle an
/// existing load. SDK presentation latency is not guaranteed.
///
/// Inline rendering uses AdBannerView and AdNativeView. App navigation,
/// cooldowns and frequency limits remain app policy.
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

  /// Package-internal presentation coordinator for native hosts.
  @internal
  static PresentationMutex? get presentationMutex => _pool?.mutex;

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
    testPool?.mutex.dispose();
    _initializationState.value = AdInitializationState.disposed;
  }

  /// Initializes consent (Google UMP + Apple ATT), native Google Mobile Ads SDK,
  /// registers native ad factories, and prepares the internal eager ad pool.
  ///
  /// Can be called immediately at boot (`main()`) before Remote Config or network placements resolve.
  /// Known non-banner [AdmobKitConfig.placements] are primed once eligible.
  /// Banners need a layout from their widget or an explicit load call.
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
    final appearance = NativeAppearance(defaults: config.nativeStyle);
    late final AdSession session;
    session = AdSession(
      config: config,
      appearance: appearance,
      driver:
          driverForTesting ??
          GoogleMobileAdsDriver(logger: _logger, analytics: config.analytics, appearance: appearance),
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

  /// Replaces global or per-placement native appearance without requesting new ads.
  /// Empty style restores inheritance. Throws on platform failure or no session.
  static Future<void> setNativeStyle(NativeAdStyle style, {NativePlacement? placement}) {
    final session = _session;
    if (session == null) return Future.error(StateError('Call initialize() before setNativeStyle().'));
    return session.setNativeStyle(style, placement: placement);
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

  /// Presents a cached SDK fullscreen ad without waiting for a download.
  ///
  /// Unavailable or blocked presentations invoke [onDismissed].
  /// Splash placements may await an existing load before checking ownership.
  /// Inline placements, including fullscreen natives, use their widgets.
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

  /// Whether a fresh buffered ad is available for this placement/layout.
  static bool isReady(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return _pool?.isReady(placement, bannerLayout: bannerLayout) ?? false;
  }

  /// Whether queued, in-flight or retry work exists for this placement/layout.
  static bool isLoading(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return _pool?.isLoading(placement, bannerLayout: bannerLayout) ?? false;
  }

  /// Returns the current lifecycle state of [placement].
  static AdPlacementState getState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return _pool?.getState(placement, bannerLayout: bannerLayout) ?? AdPlacementState.unloaded;
  }

  /// Observes state transitions for [placement] (e.g. for reactive splash waiting).
  static Stream<AdPlacementState> watchState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return _pool?.watchState(placement, bannerLayout: bannerLayout) ?? const Stream.empty();
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  ///
  /// Returns true for a ready buffered ad, or false when unavailable after
  /// denial, failure, timeout, premium gating or disposal.
  /// Waits for pending initialization/privacy resolution before loading. [timeout]
  /// applies to the ad wait, not to time spent resolving consent or the SDK.
  static Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) {
    return _session?.waitFor(placement, timeout: timeout, bannerLayout: bannerLayout) ??
        _testPool?.waitFor(placement, timeout: timeout, bannerLayout: bannerLayout) ??
        Future.value(false);
  }

  /// Waits for eligibility and requests a preload for the placement/layout.
  /// Completion is not a readiness result; use [waitFor] for that.
  static Future<void> preload(AdPlacement placement, {BannerLayout? bannerLayout}) =>
      _session?.preload(placement, bannerLayout: bannerLayout) ??
      _testPool?.preload(placement, bannerLayout: bannerLayout) ??
      Future<void>.value();

  /// Whether the user is currently entitled to an ad-free experience.
  static bool get isUserPremium => _session?.isPremium ?? _testPool?.isUserPremium ?? false;

  /// Whether SDK fullscreen or loaded active fullscreen-native ownership is held.
  /// App dialogs and paywalls are not tracked.
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
  static Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) {
    return _session?.leaseInlineAd(placement, timeout: timeout, bannerLayout: bannerLayout) ??
        _testPool?.leaseInlineAd(placement, timeout: timeout, bannerLayout: bannerLayout) ??
        Future<dynamic>.value(null);
  }

  /// Internal reference to logger.
  @internal
  static PlatformAdLogger? get logger => _logger;

  /// Freshness limit for retained inline leases.
  @internal
  static Duration get inlineAdTtl => _pool?.adTtl ?? const Duration(minutes: 50);

  /// Internal reference to pool.
  @internal
  static EagerAdPool? get pool => _pool;
}

// NOTE: The legacy `typedef FlutterAds = AdmobKit;` alias was removed.
// Use [AdmobKit] everywhere. If you still reference `FlutterAds` from an
// older integration, do a one-line find/replace to `AdmobKit` (same API,
// same members) and update the import to
// `package:admob_kit_flutter/admob_kit_flutter.dart`.
