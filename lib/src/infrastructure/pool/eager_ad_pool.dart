import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../domain/contracts/ad_analytics_tracker.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_network_info.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_placement_state.dart';
import '../../domain/models/ad_priority.dart';
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

  final Map<String, ListQueue<AdCacheEntry>> _cache = {};
  final Set<String> _consumedLoadOnceIds = {};
  final Map<String, int> _placementCapacities = {};

  /// Registered inline-lease demand per placement ID, served FIFO when the
  /// replenished ad arrives. Guarantees each waiter gets its own ad instance.
  final Map<String, ListQueue<Completer<dynamic>>> _leaseWaiters = {};

  /// Whether [dispose] has run; guards microtask-scheduled replenishments.
  bool _closed = false;

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
    Map<String, int>? placementCapacities,
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
        ) {
    if (placementCapacities != null) {
      _placementCapacities.addAll(placementCapacities);
    }
  }

  /// Sets target preloading capacity for [placementId].
  void setCapacity(String placementId, int capacity) {
    if (capacity > 0) {
      _placementCapacities[placementId] = capacity;
    }
  }

  /// Returns the target preloading capacity for [placementId] (defaults to 1).
  int getCapacity(String placementId) => _placementCapacities[placementId] ?? 1;

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
      final capacity = getCapacity(placement.id);
      for (int i = 0; i < capacity; i++) {
        preload(placement);
      }
    }
  }

  /// Triggers a background preload for [placement].
  Future<void> preload(AdPlacement placement) async {
    if (isUserPremium || _closed) return;

    if (placement.loadOnce && _consumedLoadOnceIds.contains(placement.id)) {
      _logger?.info('[Pool] Placement "${placement.id}" is loadOnce: true and already consumed. Preload skipped.');
      return;
    }

    final queue = _cache.putIfAbsent(placement.id, () => ListQueue<AdCacheEntry>());

    queue.removeWhere((entry) {
      if (entry.isStale) {
        _logger?.info('[Pool] Evicting stale ad for "${placement.id}" (Age: ${entry.age.inMinutes}m).');
        _evictEntry(entry, isStale: true);
        return true;
      }
      return false;
    });

    final buffered = queue.length;
    final pending = _queue.pendingTaskCount(placement.id);
    final openLeases = _leaseWaiters[placement.id]?.length ?? 0;
    final targetCapacity = getCapacity(placement.id);
    if (buffered + pending >= targetCapacity + openLeases) {
      _logger?.debug(
        '[Pool] Placement "${placement.id}" saturated '
        '(buffered:$buffered pending:$pending leases:$openLeases target:$targetCapacity).',
      );
      return;
    }

    _analytics?.onAdRequested(placement);

    try {
      final adInstance = await _queue.enqueue(placement);

      // Demand-based delivery: serve the oldest registered lease first so a
      // concurrent widget receives its own instance without a re-lease race.
      final waiters = _leaseWaiters[placement.id];
      if (waiters != null && waiters.isNotEmpty) {
        final waiter = waiters.removeFirst();
        if (waiters.isEmpty) _leaseWaiters.remove(placement.id);
        if (!waiter.isCompleted) waiter.complete(adInstance);
        if (placement.loadOnce) _consumedLoadOnceIds.add(placement.id);
        _queue.notifyEvicted(placement.id);
        _logger?.info('[Pool] Delivered ad for "${placement.id}" directly to a waiting lease.');

        // Buffer replenishment: after direct delivery, keep the warm buffer
        // full so the NEXT widget still gets a 0ms lease. Without this, the
        // pool starves at 0/target after every demand-served lease.
        if (!placement.loadOnce && !isUserPremium) {
          _scheduleReplenish(placement);
        }
      } else {
        queue.addLast(AdCacheEntry(
          placement: placement,
          adInstance: adInstance,
          ttl: _adTtl,
        ));
        _queue.notifyReady(placement.id);
        _logger?.info('[Pool] Buffer filled for "${placement.id}" (${queue.length}/$targetCapacity). Ready for instant display.');
      }
    } catch (error) {
      // Failure logging and retries are managed within TieredAdQueue. However,
      // no ad is coming from THIS task. Settle the oldest registered lease
      // waiter with null so it renders its empty state instantly instead of
      // hanging until its timeout (e.g. AdMob NO_FILL returning in ~200ms).
      final waiters = _leaseWaiters[placement.id];
      if (waiters != null && waiters.isNotEmpty) {
        final waiter = waiters.removeFirst();
        if (waiters.isEmpty) _leaseWaiters.remove(placement.id);
        if (!waiter.isCompleted) waiter.complete(null);
        _logger?.warning('[Pool] Ad load failed for "${placement.id}". Settling oldest lease waiter with null.');
      }
    }
  }

  /// Checks whether an ad is primed and ready in memory.
  bool isReady(AdPlacement placement) {
    if (isUserPremium) return false;

    final queue = _cache[placement.id];
    if (queue == null || queue.isEmpty) return false;

    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Pool] Ad for "${placement.id}" expired in memory. Evicting and refilling.');
      _evictEntry(stale, isStale: true);
      preload(placement);
    }

    if (queue.isEmpty) {
      _queue.notifyEvicted(placement.id);
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

    // ⚡ Dynamically promote priority so this placement preempts background tasks:
    _queue.promote(placement.id, AdPriority.immediate);

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

  /// Awaits an in-flight splash settlement, then presents it directly via the
  /// driver without re-entering [show] (the mutex is already held by this call).
  ///
  /// On failure or timeout: releases the lock and continues the user flow.
  Future<void> _settleSplashAndPresent(
    FullscreenPlacement placement, {
    VoidCallback? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) async {
    final ready = await waitFor(placement);

    final queue = _cache[placement.id];
    final entry = (ready && queue != null && queue.isNotEmpty) ? queue.removeFirst() : null;

    if (entry == null) {
      _mutex.release(placement.id, wasDisplayed: false);
      _logger?.warning(
        '[Show] Splash placement "${placement.id}" failed or timed out. Continuing user flow.',
      );
      preload(placement);
      onDismissed?.call();
      return;
    }

    if (queue != null && queue.isEmpty) {
      _queue.notifyEvicted(placement.id);
    }

    _logger?.info('[Show] Splash placement "${placement.id}" ready after await. Presenting...');
    _driver.showFullscreenAd(
      placement: placement,
      adInstance: entry.adInstance,
      onDisplayed: () => onDisplayed?.call(),
      onDismissed: () {
        _mutex.release(placement.id);
        onDismissed?.call();
        if (!placement.loadOnce) {
          _logger?.info('[Pool] Auto-replenishing recurring placement "${placement.id}" in background.');
          preload(placement);
        }
      },
      onRewardGranted: onRewardGranted,
    );
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
    if (isUserPremium) {
      _logger?.info('[Show] User is premium. Bypassing ad display for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    if (!_mutex.tryAcquire(placement.id)) {
      _logger?.warning('[Show] Presentation lock active. Dropping show request for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    final queue = _cache[placement.id];
    final cached = (queue != null && queue.isNotEmpty) ? queue.removeFirst() : null;
    if (cached != null && queue != null && queue.isEmpty) {
      _queue.notifyEvicted(placement.id);
    }

    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evictEntry(cached, isStale: true);
      }

      if (placement.isSplash && isLoading(placement)) {
        // Keep the mutex held for the whole settlement window: a pending splash
        // deterministically wins over any concurrent trigger (which is rejected).
        _logger?.info(
          '[Show] Splash placement "${placement.id}" is in-flight loading. '
          'Awaiting deterministic settlement (show, fail, or timeout)...',
        );
        _settleSplashAndPresent(
          placement,
          onDismissed: onDismissed,
          onDisplayed: onDisplayed,
          onRewardGranted: onRewardGranted,
        );
        return; // lock intentionally NOT released while settling
      }

      _mutex.release(placement.id, wasDisplayed: false);
      _logger?.info(
        '[Show] 0ms Cache Miss for "${placement.id}". Continuing user flow without delay.',
      );
      preload(placement);
      onDismissed?.call();
      return;
    }

    _logger?.info('[Show] 🎯 0ms Cache Hit for "${placement.id}". Displaying ad.');

    _driver.showFullscreenAd(
      placement: placement,
      adInstance: cached.adInstance,
      onDisplayed: () {
        onDisplayed?.call();
      },
      onDismissed: () {
        _mutex.release(placement.id);
        onDismissed?.call();

        if (!placement.loadOnce) {
          _logger?.info('[Pool] Auto-replenishing recurring placement "${placement.id}" in background.');
          preload(placement);
        }
      },
      onRewardGranted: onRewardGranted,
    );
  }

  /// Retrieves and exclusively consumes a cached inline ad (Banner/Native), refilling if recurring.
  ///
  /// Guarantees that the returned ad object is exclusively owned by the caller.
  ///
  /// If the buffer is empty, registers demand and completes when a replenished
  /// ad arrives (each waiter receives its own distinct instance), or returns
  /// `null` after [timeout] elapses without settlement.
  Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout}) async {
    if (isUserPremium || _closed) return null;

    final queue = _cache.putIfAbsent(placement.id, () => ListQueue<AdCacheEntry>());

    // Evict any stale ads from the head of the buffer
    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Pool] Evicting stale inline ad for "${placement.id}".');
      _evictEntry(stale, isStale: true);
    }

    // 🚀 Exclusive Destructive Pop: No other widget can receive this ad object!
    final entry = queue.isNotEmpty ? queue.removeFirst() : null;

    if (entry != null) {
      if (queue.isEmpty) {
        _queue.notifyEvicted(placement.id);
      }
      if (placement.loadOnce) {
        _consumedLoadOnceIds.add(placement.id);
      } else {
        _logger?.info('[Pool] Auto-replenishing recurring inline placement "${placement.id}".');
        preload(placement);
      }
      return entry.adInstance;
    }

    // Buffer empty: register demand and let the pool deliver on arrival.
    // Promote to immediate so a user-visible ad never queues behind
    // low-priority background preloads.
    _queue.promote(placement.id, AdPriority.immediate);

    final waiter = Completer<dynamic>();
    _leaseWaiters.putIfAbsent(placement.id, () => ListQueue<Completer<dynamic>>()).addLast(waiter);
    preload(placement); // no-op when a task is already pending (saturation check)

    final effectiveTimeout = timeout ?? _timeoutConfig.resolve(
      format: placement.format,
      network: await _networkInfo.getNetworkType(),
      isSplash: placement.isSplash,
    );

    return waiter.future.timeout(effectiveTimeout, onTimeout: () {
      _leaseWaiters[placement.id]?.remove(waiter);
      if (_leaseWaiters[placement.id]?.isEmpty ?? false) {
        _leaseWaiters.remove(placement.id);
      }
      _logger?.warning('[Pool] Inline lease for "${placement.id}" timed out. Returning null.');
      return null;
    });
  }

  /// Schedules a microtask-level buffer replenishment without blocking the
  /// current caller. No-ops when the buffer+pending already meet target.
  void _scheduleReplenish(AdPlacement placement) {
    scheduleMicrotask(() {
      if (_closed || (_leaseWaiters[placement.id]?.isNotEmpty ?? false)) {
        // Waiters get priority; the load triggered by their lease already ran.
        return;
      }
      preload(placement);
    });
  }

  void _evictEntry(AdCacheEntry entry, {bool isStale = false}) {
    if (isStale) {
      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: entry.placement.id,
          format: entry.placement.format,
          eventType: AdDiagnosticEventType.staleEvicted,
          elapsed: entry.age,
          networkType: 'unknown',
        ),
      );
    }
    entry.dispose();
  }

  /// Disposes queue, cache, lease waiters, and mutex.
  void dispose() {
    _closed = true;
    _queue.dispose();
    for (final entry in _cache.values.expand((q) => q)) {
      entry.dispose();
    }
    _cache.clear();
    for (final waiters in _leaseWaiters.values) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) waiter.complete(null);
      }
    }
    _leaseWaiters.clear();
    _mutex.forceRelease();
  }
}
