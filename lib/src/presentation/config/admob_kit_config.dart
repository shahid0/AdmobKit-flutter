import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_logger.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_timeout_config.dart';
import '../../infrastructure/consent/consent_coordinator.dart';
import '../../infrastructure/pool/retry_scheduler.dart';

/// Configuration passed to [AdmobKit.initialize] at application startup.
class AdmobKitConfig {
  /// The initial catalog of ad placements to register.
  ///
  /// If provided, placements are primed during [AdmobKit.initialize].
  /// Placements can also be registered later via [AdmobKit.registerPlacements]
  /// once remote configs are loaded.
  final List<AdPlacement>? placements;

  /// Whether to automatically execute Google UMP and Apple ATT consent before priming ads.
  final bool requestConsent;

  /// The test configuration for Google UMP (e.g. simulating EEA geography).
  final ConsentTestConfig? consentTestConfig;

  /// The universal entitlement gate callback.
  ///
  /// If this callback returns `true`, all ad preloads, retries, and display calls are bypassed.
  final bool Function()? isPremium;

  /// The adaptive network timeout policy (defaults to [AdTimeoutConfig.standard]).
  final AdTimeoutConfig timeouts;

  /// The custom retry scheduler policy (exponential backoff + jitter).
  final RetryScheduler? retryScheduler;

  /// The injected analytics tracker for impression-level revenue and funnel events.
  final AdAnalyticsTracker? analytics;

  /// The injected diagnostics tracker for opt-in production debugging of slow networks/timeouts.
  final AdDiagnosticsTracker? diagnostics;

  /// The console logging verbosity (defaults to verbose in debug mode, silent in release mode).
  final AdLogLevel? logLevel;

  /// The list of AdMob test device hashed IDs.
  final List<String>? testDeviceIds;

  /// Whether to initialize the native Google Mobile Ads SDK.
  ///
  /// Set to `false` in widget/unit test environments to avoid hanging on native platform channels.
  final bool initializeNativeGma;

  /// The in-memory cache time-to-live before an ad is considered stale (defaults to 50 minutes).
  final Duration adTtl;

  /// The maximum concurrent in-flight ad downloads during initial app startup (defaults to 1).
  ///
  /// Set to 1 by default to optimize for slow/cellular networks, preventing multiple ad downloads
  /// from congesting the radio and causing latency spikes or timeouts.
  final int initialConcurrency;

  /// The maximum concurrent in-flight ad downloads for subsequent ad preloads and auto-replenishments (defaults to 1).
  final int subsequentConcurrency;

  /// Creates a new [AdmobKitConfig] instance.
  const AdmobKitConfig({
    this.placements,
    this.requestConsent = true,
    this.consentTestConfig,
    this.isPremium,
    this.timeouts = AdTimeoutConfig.standard,
    this.retryScheduler,
    this.analytics,
    this.diagnostics,
    this.logLevel,
    this.testDeviceIds,
    this.initializeNativeGma = true,
    this.adTtl = const Duration(minutes: 50),
    this.initialConcurrency = 1,
    this.subsequentConcurrency = 1,
  });
}

/// Backwards-compatible alias for [AdmobKitConfig].
typedef FlutterAdsConfig = AdmobKitConfig;
