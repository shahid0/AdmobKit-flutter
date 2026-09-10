import 'package:flutter/foundation.dart';
import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_network_info.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_placement_state.dart';
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
  final AdNetworkInfo _networkInfo;
  final AdTimeoutConfig _timeoutConfig;
  final PlatformAdLogger? _logger;
  final AdAnalyticsTracker? _analytics;
  final AdDiagnosticsTracker? _diagnostics;
  final bool Function()? _isPremium;
  final Duration _adTtl;

  final Map<String, AdCacheEntry> _cache = {};
  final Set<String> _consumedLoadOnceIds = {};

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
    int initialConcurrency = 1,
    int subsequentConcurrency = 1,
  })  : _driver = driver,
        _mutex = mutex,
        _networkInfo = networkInfo,
        _timeoutConfig = timeoutConfig ?? AdTimeoutConfig.standard,
        _logger = logger,
        _analytics = analytics,
        _diagnostics = diagnostics,
        _isPremium = isPremium,
        _adTtl = adTtl,
        _queue = TieredAdQueue(
          executor: (placement) => driver.loadAd(placement),
          networkInfo: networkInfo,
          timeoutConfig: timeoutConfig ?? AdTimeoutConfig.standard,
          retryScheduler: retryScheduler,
          logger: logger,
          diagnostics: diagnostics,
          initialConcurrency: initialConcurrency,
          subsequentConcurrency: subsequentConcurrency,
        );

  /// Returns true if user is currently entitled to an ad-free experience.
  bool get isUserPremium => _isPremium?.call() ?? false;

  /// Returns the underlying presentation mutex.
  PresentationMutex get mutex => _mutex;

  /// Primes a list of placements at app startup according to their priority tiers.
  void primeAll(Iterable<AdPlacement> placements) {
    if (isUserPremium) {
      _logger?.info('[Pool] User is premium. Skipping initial ad preloading.');
      return;
    }

    _queue.markInitialBatch(placements.map((p) => p.id));

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

    // Placements configured as loadOnce (e.g. splash, onboarding) are never re-preloaded
    if (placement.loadOnce && _consumedLoadOnceIds.contains(placement.id)) {
      _logger?.info('[Pool] Placement "${placement.id}" is loadOnce: true and already consumed. Preload skipped.');
      return;
    }

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
      _queue.notifyReady(placement.id);
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

  /// Checks whether [placement] is currently in-flight downloading.
  bool isLoading(AdPlacement placement) {
    return _queue.isLoading(placement.id);
  }

  /// Returns the current lifecycle state of [placement].
  AdPlacementState getState(AdPlacement placement) {
    if (isReady(placement)) return AdPlacementState.ready;
    return _queue.getState(placement.id);
  }

  /// Observes state transitions for [placement].
  Stream<AdPlacementState> watchState(AdPlacement placement) {
    return _queue.watchState(placement.id);
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  ///
  /// Returns `true` if the ad is ready in memory; `false` if failed, timed out, or user is premium.
  Future<bool> waitFor(AdPlacement placement, {Duration? timeout}) async {
    if (isUserPremium) return false;
    if (isReady(placement)) return true;
    if (getState(placement) == AdPlacementState.error) return false;

    Duration effectiveTimeout;
    if (timeout != null) {
      effectiveTimeout = timeout;
    } else {
      final network = await _networkInfo.getNetworkType();
      effectiveTimeout = _timeoutConfig.resolve(
        format: placement.format,
        network: network,
        isSplash: placement.isSplash,
      );
    }

    try {
      final terminalState = await watchState(placement)
          .firstWhere((s) => s == AdPlacementState.ready || s == AdPlacementState.error)
          .timeout(effectiveTimeout);
      return terminalState == AdPlacementState.ready;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForSplashAndShow(
    FullscreenPlacement placement, {
    VoidCallback? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) async {
    final ready = await waitFor(placement);
    if (ready) {
      _logger?.info('[Show] Splash placement "${placement.id}" ready after await. Presenting...');
      show(
        placement,
        onDismissed: onDismissed,
        onDisplayed: onDisplayed,
        onRewardGranted: onRewardGranted,
      );
    } else {
      _logger?.warning(
        '[Show] Splash placement "${placement.id}" failed or timed out. Continuing user flow.',
      );
      onDismissed?.call();
    }
  }

  /// Shows a full-screen ad following the 0ms Non-Blocking Dumb View Contract.
  ///
  /// - If ready: presents immediately with zero perceived user wait.
  /// - If unready / offline: invokes [onDismissed] immediately without blocking user flow.
  /// - If splash and currently loading: deterministically awaits settlement (show, fail, or timeout).
  /// - Upon dismissal: releases lock and auto-replenishes unless [placement.loadOnce] is true.
  void show(
    FullscreenPlacement placement, {
    VoidCallback? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) {
    // 1. Premium Guard
    if (isUserPremium) {
      _logger?.info('[Show] User is premium. Bypassing ad display for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    // 2. Mutual Exclusion (Presentation Mutex)
    if (!_mutex.tryAcquire(placement.id)) {
      _logger?.warning('[Show] Presentation lock active. Dropping show request for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    // 3. Freshness & Cache Check
    final cached = _cache.remove(placement.id);
    if (cached != null) {
      _queue.notifyEvicted(placement.id);
    }
    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evict(placement.id, isStale: true);
      }
      _mutex.release(placement.id, wasDisplayed: false);

      // Deterministic splash settlement: if splash placement is in-flight loading, await settlement
      if (placement.isSplash && isLoading(placement)) {
        _logger?.info(
          '[Show] Splash placement "${placement.id}" is in-flight loading. '
          'Awaiting deterministic settlement (show, fail, or timeout)...',
        );
        _waitForSplashAndShow(
          placement,
          onDismissed: onDismissed,
          onDisplayed: onDisplayed,
          onRewardGranted: onRewardGranted,
        );
        return;
      }

      _logger?.info(
        '[Show] 0ms Cache Miss for "${placement.id}". Continuing user flow without delay.',
      );
      // Trigger background reload so it's primed next time
      preload(placement);
      onDismissed?.call();
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
        onDismissed?.call();

        // 5. Replenish unless marked as loadOnce funnel
        if (!placement.loadOnce) {
          _logger?.info('[Pool] Auto-replenishing recurring placement "${placement.id}" in background.');
          preload(placement);
        } else {
          _consumedLoadOnceIds.add(placement.id);
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
    if (cached != null) {
      _queue.notifyEvicted(placement.id);
    }
    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evict(placement.id, isStale: true);
      }
      if (!placement.loadOnce || !_consumedLoadOnceIds.contains(placement.id)) {
        preload(placement);
      }
      return null;
    }

    // Trigger replenishment for future renders unless marked as loadOnce funnel
    if (placement.loadOnce) {
      _consumedLoadOnceIds.add(placement.id);
      _logger?.info('[Pool] Inline placement "${placement.id}" is loadOnce: true. Replenishment skipped.');
    } else {
      _logger?.info('[Pool] Auto-replenishing recurring inline placement "${placement.id}".');
      preload(placement);
    }
    return cached.adInstance;
  }

  void _evict(String placementId, {bool isStale = false}) {
    final entry = _cache.remove(placementId);
    _queue.notifyEvicted(placementId);
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
