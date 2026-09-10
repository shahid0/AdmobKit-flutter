import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_logger.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_timeout_config.dart';
import '../../infrastructure/consent/consent_coordinator.dart';
import '../../infrastructure/pool/retry_scheduler.dart';

/// Configuration passed to [FlutterAds.initialize] at application startup.
class FlutterAdsConfig {
  /// Optional initial catalog of ad placements to register.
  /// If provided, placements are primed during [FlutterAds.initialize].
  /// Alternatively, placements can be registered later via [FlutterAds.registerPlacements]
  /// once remote configs are loaded.
  final List<AdPlacement>? placements;

  /// If true, automatically executes Google UMP and Apple ATT consent before priming ads.
  final bool requestConsent;

  /// Optional test configuration for Google UMP (e.g. simulating EEA geography).
  final ConsentTestConfig? consentTestConfig;

  /// Universal entitlement gate callback.
  /// If returns `true`, all ad preloads, retries, and display calls are bypassed.
  final bool Function()? isPremium;

  /// Adaptive network timeout policy (defaults to [AdTimeoutConfig.standard]).
  final AdTimeoutConfig timeouts;

  /// Custom retry scheduler policy (exponential backoff + jitter).
  final RetryScheduler? retryScheduler;

  /// Injected analytics tracker for impression-level revenue and funnel events.
  final AdAnalyticsTracker? analytics;

  /// Injected diagnostics tracker for opt-in production debugging of slow networks/timeouts.
  final AdDiagnosticsTracker? diagnostics;

  /// Console logging verbosity (defaults to verbose in debug mode, silent in release mode).
  final AdLogLevel? logLevel;

  /// AdMob test device hashed IDs.
  final List<String>? testDeviceIds;

  /// If true, initializes the native Google Mobile Ads SDK.
  /// Set to false in widget/unit test environments to avoid hanging on native platform channels.
  final bool initializeNativeGma;

  /// In-memory cache time-to-live before an ad is considered stale (defaults to 50 minutes).
  final Duration adTtl;

  const FlutterAdsConfig({
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
  });
}
