import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/models/ad_initialization_state.dart';
import '../domain/models/ad_placement.dart';
import '../domain/models/ad_placement_state.dart';
import '../domain/models/banner_layout.dart';
import '../domain/models/native_ad_style.dart';
import 'ad_runtime.dart';
import 'config/admob_kit_config.dart';

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
  /// Current consent/SDK stage. This is separate from individual ad readiness.
  static AdInitializationState get initializationState => adInitializationStateListenable.value;

  /// Observable stage, suitable for ValueListenableBuilder without polling.
  static ValueListenable<AdInitializationState> get initializationStateListenable => adInitializationStateListenable;

  /// Disposes the eager ad pool and releases all locks and resources.
  static void dispose() => disposeAdSession();

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
  static Future<void> initialize({AdmobKitConfig config = const AdmobKitConfig()}) =>
      initializeAdSession(config: config);

  /// Replaces global or per-placement native appearance without requesting new ads.
  /// Empty style restores inheritance. Throws on platform failure or no session.
  static Future<void> setNativeStyle(NativeAdStyle style, {NativePlacement? placement}) {
    final session = activeAdSession;
    if (session == null) return Future.error(StateError('Call initialize() before setNativeStyle().'));
    return session.setNativeStyle(style, placement: placement);
  }

  /// Stage 2: Registers and primes placements in the eager preloading pool.
  ///
  /// Call this as soon as your ad configuration is ready (e.g. after Firebase Remote Config
  /// or backend API has loaded). Can be called multiple times to register new placements.
  static void registerPlacements(Iterable<AdPlacement> placements, {Map<String, int>? placementCapacities}) {
    final session = activeAdSession;
    if (session == null) {
      throw StateError('Call initialize() before registerPlacements().');
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
    final session = activeAdSession;
    if (session != null) {
      session.show(placement, onDismissed: onDismissed, onRewardGranted: onRewardGranted, onDisplayed: onDisplayed);
      return;
    }
    adSessionLogger?.warning('[AdmobKit] show() called before initialize(). Proceeding.');
    onDismissed?.call();
  }

  /// Whether a fresh buffered ad is available for this placement/layout.
  static bool isReady(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return activeAdSession?.pool.isReady(placement, bannerLayout: bannerLayout) ?? false;
  }

  /// Whether queued, in-flight or retry work exists for this placement/layout.
  static bool isLoading(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return activeAdSession?.pool.isLoading(placement, bannerLayout: bannerLayout) ?? false;
  }

  /// Returns the current lifecycle state of [placement].
  static AdPlacementState getState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return activeAdSession?.pool.getState(placement, bannerLayout: bannerLayout) ?? AdPlacementState.unloaded;
  }

  /// Observes buffer state for diagnosis. Use [waitFor] for an ad decision.
  static Stream<AdPlacementState> watchState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    return activeAdSession?.pool.watchState(placement, bannerLayout: bannerLayout) ?? const Stream.empty();
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  ///
  /// Returns true for a ready buffered ad, or false when unavailable after
  /// denial, failure, timeout, premium gating or disposal.
  /// Waits for pending initialization/privacy resolution before loading. [timeout]
  /// applies to the ad wait, not to time spent resolving consent or the SDK.
  static Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) {
    return activeAdSession?.waitFor(placement, timeout: timeout, bannerLayout: bannerLayout) ?? Future.value(false);
  }

  /// Whether the user is currently entitled to an ad-free experience.
  static bool get isUserPremium => activeAdSession?.isPremium ?? false;

  /// Whether SDK fullscreen or loaded active fullscreen-native ownership is held.
  /// App dialogs and paywalls are not tracked.
  static bool get isShowingAd => activeAdSession?.pool.mutex.isLocked ?? false;

  /// Snapshot: consent AND SDK/factories are ready and the user is not premium.
  /// False can mean still resolving. Await [waitUntilCanRequestAds] for a decision.
  static bool get canRequestAds => activeAdSession?.canRequestAds ?? false;

  /// Waits for consent, ATT, SDK initialization and native factory registration.
  /// Returns false only for a settled denial/failure, premium, disposal, or when
  /// initialize has not been called. Does not start initialization implicitly.
  static Future<bool> waitUntilCanRequestAds() =>
      activeAdSession?.waitUntilCanRequestAds() ?? Future.value(canRequestAds);

  /// Waits for initialization, then reports whether UMP requires a settings link.
  /// A consent denial does not suppress this check. SDK query errors propagate.
  static Future<bool> isPrivacyOptionsRequired() => activeAdSession?.isPrivacyOptionsRequired() ?? Future.value(false);

  /// Presents the Google UMP privacy options form so users can update consent in settings.
  static Future<bool> showPrivacyOptionsForm() async {
    return activeAdSession?.showPrivacyOptionsForm() ?? Future.value(false);
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
}
