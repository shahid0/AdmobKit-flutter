import 'package:flutter/foundation.dart';
import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_network_info.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_timeout_config.dart';
import '../../domain/models/diagnostic_report.dart';
import '../drivers/google_mobile_ads_driver.dart';
import '../logging/platform_ad_logger.dart';
import '../mutex/presentation_mutex.dart';
import 'ad_cache_entry.dart';
import 'retry_scheduler.dart';
import 'tiered_ad_queue.dart';

/// Central eager ad preloading pool coordinating caching, replenishment,
/// 0ms presentations, and entitlement enforcement.
class EagerAdPool {
  final GoogleMobileAdsDriver _driver;
  final PresentationMutex _mutex;
  final TieredAdQueue _queue;
  final PlatformAdLogger? _logger;
  final AdAnalyticsTracker? _analytics;
  final AdDiagnosticsTracker? _diagnostics;
  final bool Function()? _isPremium;
  final Duration _adTtl;

  final Map<String, AdCacheEntry> _cache = {};

  EagerAdPool({
    required GoogleMobileAdsDriver driver,
    required PresentationMutex mutex,
    required AdNetworkInfo networkInfo,
    AdTimeoutConfig? timeoutConfig,
    RetryScheduler? retryScheduler,
    PlatformAdLogger? logger,
    AdAnalyticsTracker? analytics,
    AdDiagnosticsTracker? diagnostics,
    bool Function()? isPremium,
    Duration adTtl = const Duration(minutes: 50),
  })  : _driver = driver,
        _mutex = mutex,
        _logger = logger,
        _analytics = analytics,
        _diagnostics = diagnostics,
        _isPremium = isPremium,
        _adTtl = adTtl,
        _queue = TieredAdQueue(
          executor: (placement) => driver.loadAd(placement),
          networkInfo: networkInfo,
          timeoutConfig: timeoutConfig,
          retryScheduler: retryScheduler,
          logger: logger,
          diagnostics: diagnostics,
        );

  /// Returns true if user is currently entitled to an ad-free experience.
  bool get isUserPremium => _isPremium?.call() ?? false;

  /// Returns the underlying presentation mutex.
  PresentationMutex get mutex => _mutex;

  /// Primes a list of placements at app startup according to their priority tiers.
  void primeAll(List<AdPlacement> placements) {
    if (isUserPremium) {
      _logger?.info('[Pool] User is premium. Skipping initial ad preloading.');
      return;
    }

    _logger?.info('[Pool] 🚀 Priming startup queue with ${placements.length} placement(s)...');
    final sorted = List<AdPlacement>.from(placements)
      ..sort((a, b) => a.priority.rank.compareTo(b.priority.rank));

    for (final placement in sorted) {
      preload(placement);
    }
  }

  /// Triggers a background preload for [placement].
  Future<void> preload(AdPlacement placement) async {
    if (isUserPremium) return;

    // Check if valid cached ad already exists
    final cached = _cache[placement.id];
    if (cached != null) {
      if (!cached.isStale) {
        _logger?.debug('[Pool] Placement "${placement.id}" is already primed and fresh.');
        return;
      } else {
        _logger?.info('[Pool] Evicting stale ad for "${placement.id}" (Age: ${cached.age.inMinutes}m).');
        _evict(placement.id, isStale: true);
      }
    }

    _analytics?.onAdRequested(placement);

    try {
      final adInstance = await _queue.enqueue(placement);
      _cache[placement.id] = AdCacheEntry(
        placement: placement,
        adInstance: adInstance,
        ttl: _adTtl,
      );
      _logger?.info('[Pool] Buffer filled for "${placement.id}". Ready for instant display.');
    } catch (_) {
      // Failure logging and retries are managed within TieredAdQueue
    }
  }

  /// Checks whether an ad is primed and ready in memory.
  bool isReady(AdPlacement placement) {
    if (isUserPremium) return false;

    final cached = _cache[placement.id];
    if (cached == null) return false;

    if (cached.isStale) {
      _logger?.info('[Pool] Ad for "${placement.id}" expired in memory. Evicting and refilling.');
      _evict(placement.id, isStale: true);
      preload(placement);
      return false;
    }

    return true;
  }

  /// Shows a full-screen ad following the 0ms Non-Blocking Dumb View Contract.
  ///
  /// - If ready: presents immediately with zero perceived user wait.
  /// - If unready / offline: invokes [onDismissed] immediately without blocking user flow.
  /// - Upon dismissal: releases lock and auto-replenishes unless [placement.loadOnce] is true.
  void show(
    FullscreenPlacement placement, {
    required VoidCallback onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) {
    // 1. Premium Guard
    if (isUserPremium) {
      _logger?.info('[Show] User is premium. Bypassing ad display for "${placement.id}".');
      onDismissed();
      return;
    }

    // 2. Mutual Exclusion (Presentation Mutex)
    if (!_mutex.tryAcquire(placement.id)) {
      _logger?.warning('[Show] Presentation lock active. Dropping show request for "${placement.id}".');
      onDismissed();
      return;
    }

    // 3. Freshness & Cache Check
    final cached = _cache.remove(placement.id);
    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evict(placement.id, isStale: true);
      }
      _mutex.release(placement.id);
      _logger?.info(
        '[Show] 0ms Cache Miss for "${placement.id}". Continuing user flow without delay.',
      );
      // Trigger background reload so it's primed next time
      preload(placement);
      onDismissed();
      return;
    }

    _logger?.info('[Show] 🎯 0ms Cache Hit for "${placement.id}". Displaying ad.');

    // 4. Present via Driver
    _driver.showFullscreenAd(
      placement: placement,
      adInstance: cached.adInstance,
      onDisplayed: () {
        onDisplayed?.call();
      },
      onDismissed: () {
        _mutex.release(placement.id);
        onDismissed();

        // 5. Replenish unless marked as loadOnce funnel
        if (!placement.loadOnce) {
          _logger?.info('[Pool] Auto-replenishing recurring placement "${placement.id}" in background.');
          preload(placement);
        } else {
          _logger?.info('[Pool] Placement "${placement.id}" is loadOnce: true. Replenishment skipped.');
        }
      },
      onRewardGranted: onRewardGranted,
    );
  }

  /// Retrieves and consumes a cached inline ad (Banner/Native), refilling if recurring.
  dynamic leaseInlineAd(InlinePlacement placement) {
    if (isUserPremium) return null;

    final cached = _cache.remove(placement.id);
    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evict(placement.id, isStale: true);
      }
      preload(placement);
      return null;
    }

    // Trigger replenishment for future renders
    preload(placement);
    return cached.adInstance;
  }

  void _evict(String placementId, {bool isStale = false}) {
    final entry = _cache.remove(placementId);
    if (entry != null) {
      if (isStale) {
        _diagnostics?.onDiagnosticReport(
          AdDiagnosticReport(
            placementId: placementId,
            format: entry.placement.format,
            eventType: AdDiagnosticEventType.staleEvicted,
            elapsed: entry.age,
            networkType: 'unknown',
          ),
        );
      }
      entry.dispose();
    }
  }

  /// Disposes queue, cache, and mutex.
  void dispose() {
    _queue.dispose();
    for (final entry in _cache.values) {
      entry.dispose();
    }
    _cache.clear();
    _mutex.forceRelease();
  }
}
