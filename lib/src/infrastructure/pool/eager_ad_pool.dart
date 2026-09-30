import 'dart:async';
import 'dart:collection';
import '../../domain/models/banner_layout.dart';
import '../../domain/models/ad_request_key.dart';
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
  final bool Function()? _canRequestAds;
  final Duration _adTtl;

  final Map<AdRequestKey, ListQueue<AdCacheEntry>> _cache = {};
  final Set<String> _consumedLoadOnceIds = {};
  final Set<String> _settlingPresentations = {};
  final Map<String, int> _placementCapacities;
  final Map<String, AdPlacement> _placements = {};
  final Map<String, BannerLayout> _preferredBannerLayouts = {};

  /// Registered inline-lease demand per placement ID, served FIFO when the
  /// replenished ad arrives. Guarantees each waiter gets its own ad instance.
  final Map<AdRequestKey, ListQueue<Completer<dynamic>>> _leaseWaiters = {};

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
    bool Function()? canRequestAds,
    Duration adTtl = const Duration(minutes: 50),
    int initialConcurrency = 1,
    int subsequentConcurrency = 1,
    Map<String, int>? placementCapacities,
  }) : _driver = driver,
       _mutex = mutex,
       _networkInfo = networkInfo,
       _timeoutConfig = timeoutConfig ?? AdTimeoutConfig.standard,
       _logger = logger,
       _analytics = analytics,
       _diagnostics = diagnostics,
       _isPremium = isPremium,
       _canRequestAds = canRequestAds,
       _adTtl = adTtl,
       _placementCapacities = _validateCapacities(placementCapacities),
       _queue = TieredAdQueue(
         executor: (placement, {bannerLayout, validateRequest}) {
           if (!(canRequestAds?.call() ?? true) || (isPremium?.call() ?? false)) {
             throw AdTaskCancelledException(placement.id);
           }
           return driver.loadAd(
             placement,
             bannerLayout: bannerLayout,
             validateRequest: () {
               validateRequest?.call();
               if (!(canRequestAds?.call() ?? true) || (isPremium?.call() ?? false)) {
                 throw AdTaskCancelledException(placement.id);
               }
             },
           );
         },
         networkInfo: networkInfo,
         timeoutConfig: timeoutConfig ?? AdTimeoutConfig.standard,
         retryScheduler: retryScheduler,
         logger: logger,
         diagnostics: diagnostics,
         initialConcurrency: initialConcurrency,
         subsequentConcurrency: subsequentConcurrency,
       );

  static Map<String, int> _validateCapacities(Map<String, int>? capacities) {
    final result = Map<String, int>.of(capacities ?? const {});
    for (final capacity in result.values) {
      if (capacity <= 0) throw ArgumentError.value(capacity, 'capacity', 'Must be positive');
    }
    return result;
  }

  /// Sets target preloading capacity for [placementId].
  void setCapacity(String placementId, int capacity) {
    if (capacity <= 0) throw ArgumentError.value(capacity, 'capacity', 'Must be positive');
    _placementCapacities[placementId] = capacity;
  }

  /// Returns the target preloading capacity for [placementId] (defaults to 1).
  int getCapacity(String placementId) => _placementCapacities[placementId] ?? 1;

  /// Returns true if user is currently entitled to an ad-free experience.
  bool get isUserPremium => _isPremium?.call() ?? false;

  bool get _adsAllowed => !_closed && !isUserPremium && (_canRequestAds?.call() ?? true);

  /// A placement ID has one immutable configuration during this pool lifetime.
  void validatePlacement(AdPlacement placement) {
    final previous = _placements[placement.id];
    if (previous != null &&
        (previous.runtimeType != placement.runtimeType ||
            previous.androidId != placement.androidId ||
            previous.iosId != placement.iosId ||
            previous.loadOnce != placement.loadOnce ||
            previous.isSplash != placement.isSplash ||
            previous.priority != placement.priority ||
            (previous is BannerPlacement && placement is BannerPlacement && previous.sizing != placement.sizing) ||
            (previous is NativePlacement &&
                placement is NativePlacement &&
                (previous.template != placement.template || previous.colors != placement.colors)))) {
      throw ArgumentError('Conflicting configuration for placement "${placement.id}". Use a distinct placement ID.');
    }
    _placements[placement.id] = placement;
  }

  void _validateRequest(AdPlacement placement, BannerLayout? layout) {
    validatePlacement(placement);
    if (placement is BannerPlacement) {
      if (layout == null) throw ArgumentError('Banner requests require a BannerLayout.');
      layout.validate();
      if (placement.sizing.maxHeight != null && placement.sizing.maxHeight! < 32) {
        throw ArgumentError('Inline banner maxHeight must be at least 32 logical pixels.');
      }
    } else if (layout != null) {
      throw ArgumentError('BannerLayout is only valid for banner placements.');
    }
  }

  void _makeBannerCacheRoom(String placementId) {
    final entries = _cache.entries.where((entry) => entry.key.placementId == placementId);
    while (entries.fold<int>(0, (total, entry) => total + entry.value.length) >= getCapacity(placementId)) {
      final oldest = entries
          .where((entry) => entry.value.isNotEmpty)
          .reduce((a, b) => a.value.first.loadedAt.isBefore(b.value.first.loadedAt) ? a : b);
      _evictEntry(oldest.value.removeFirst());
      _queue.notifyEvicted(placementId, bannerLayout: oldest.key.bannerLayout);
    }
  }

  /// Whether background preloading has stopped for this loadOnce placement.
  /// This does not prevent serving buffered ads or new inline widget demand.
  bool isConsumed(AdPlacement placement) {
    return placement.loadOnce && _consumedLoadOnceIds.contains(placement.id);
  }

  /// Marks [placement] as consumed if configured with `loadOnce: true`.
  ///
  /// Stops background preloading without invalidating other available ads.
  void _markConsumed(AdPlacement placement, {BannerLayout? bannerLayout}) {
    if (!placement.loadOnce) return;
    _consumedLoadOnceIds.add(placement.id);
    if (_cache[(placementId: placement.id, bannerLayout: bannerLayout)]?.isNotEmpty ?? false) {
      _queue.notifyReady(placement.id, bannerLayout: bannerLayout);
    } else {
      _queue.notifyEvicted(placement.id, bannerLayout: bannerLayout);
    }
  }

  /// Returns the underlying presentation mutex.
  PresentationMutex get mutex => _mutex;

  Duration get adTtl => _adTtl;

  /// Primes a list of placements at app startup according to their priority tiers.
  void primeAll(Iterable<AdPlacement> placements) {
    for (final placement in placements) {
      validatePlacement(placement);
    }
    if (!_adsAllowed) {
      _logger?.info('[Pool] Ads unavailable. Skipping initial ad preloading.');
      return;
    }

    _queue.markInitialBatch(placements.where((p) => p is! BannerPlacement).map((p) => p.id));

    _logger?.info('[Pool] 🚀 Priming startup queue with ${placements.length} placement(s)...');
    final sorted = placements.where((placement) => placement is! BannerPlacement).toList()
      ..sort((a, b) => a.priority.rank.compareTo(b.priority.rank));

    for (final placement in sorted) {
      validatePlacement(placement);
      final capacity = getCapacity(placement.id);
      for (int i = 0; i < capacity; i++) {
        preload(placement);
      }
    }
  }

  /// Triggers a background preload for [placement].
  Future<void> preload(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    if (bannerLayout != null) _preferredBannerLayouts[placement.id] = bannerLayout;
    return _load(placement, bannerLayout: bannerLayout);
  }

  Future<void> _load(
    AdPlacement placement, {
    bool forInlineDemand = false,
    bool background = false,
    BannerLayout? bannerLayout,
  }) async {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return;

    if (isConsumed(placement) && !forInlineDemand) {
      _logger?.info('[Pool] Placement "${placement.id}" is loadOnce: true and already consumed. Preload skipped.');
      return;
    }

    final queue = _cache.putIfAbsent((
      placementId: placement.id,
      bannerLayout: bannerLayout,
    ), () => ListQueue<AdCacheEntry>());

    queue.removeWhere((entry) {
      if (entry.isStale) {
        _logger?.info('[Pool] Evicting stale ad for "${placement.id}" (Age: ${entry.age.inMinutes}m).');
        _evictEntry(entry, isStale: true);
        return true;
      }
      return false;
    });

    final buffered = queue.length;
    if (background && placement is BannerPlacement) {
      final totalBuffered = _cache.entries
          .where((entry) => entry.key.placementId == placement.id)
          .fold<int>(0, (total, entry) => total + entry.value.length);
      if (totalBuffered + _queue.pendingTaskCount(placement.id, allLayouts: true) >= getCapacity(placement.id)) return;
    }
    final pending = _queue.pendingTaskCount(placement.id, bannerLayout: bannerLayout);
    final openLeases = _leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)]?.length ?? 0;
    final targetCapacity = getCapacity(placement.id);
    final effectiveCapacity = placement.loadOnce
        ? (forInlineDemand && openLeases > targetCapacity ? openLeases : targetCapacity)
        : targetCapacity + openLeases;
    if (buffered + pending >= effectiveCapacity) {
      _logger?.debug(
        '[Pool] Placement "${placement.id}" saturated '
        '(buffered:$buffered pending:$pending leases:$openLeases target:$effectiveCapacity).',
      );
      return;
    }

    _analytics?.onAdRequested(placement);

    try {
      final adInstance = await _queue.enqueue(
        placement,
        bannerLayout: bannerLayout,
        overridePriority: forInlineDemand ? AdPriority.immediate : null,
      );
      if (!_adsAllowed) {
        AdCacheEntry.disposeAdInstance(adInstance);
        _queue.notifyEvicted(placement.id, bannerLayout: bannerLayout);
        throw AdTaskCancelledException(placement.id);
      }

      // Demand-based delivery: serve the oldest registered lease first so a
      // concurrent widget receives its own instance without a re-lease race.
      final waiters = _leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)];
      if (waiters != null && waiters.isNotEmpty) {
        final waiter = waiters.removeFirst();
        if (waiters.isEmpty) _leaseWaiters.remove((placementId: placement.id, bannerLayout: bannerLayout));
        if (!waiter.isCompleted) waiter.complete(adInstance);
        if (placement.loadOnce) {
          _markConsumed(placement, bannerLayout: bannerLayout);
        } else {
          _queue.notifyEvicted(placement.id, bannerLayout: bannerLayout);
        }
        _logger?.info('[Pool] Delivered ad for "${placement.id}" directly to a waiting lease.');

        // Buffer replenishment: after direct delivery, keep the warm buffer
        // full so the NEXT widget still gets a 0ms lease. Without this, the
        // pool starves at 0/target after every demand-served lease.
        if (!placement.loadOnce && !isUserPremium) {
          _scheduleReplenish(placement, bannerLayout: bannerLayout);
        }
      } else {
        if (placement is BannerPlacement) _makeBannerCacheRoom(placement.id);
        queue.addLast(AdCacheEntry(placement: placement, adInstance: adInstance, ttl: _adTtl));
        _queue.notifyReady(placement.id, bannerLayout: bannerLayout);
        _logger?.info(
          '[Pool] Buffer filled for "${placement.id}" (${queue.length}/$targetCapacity). Ready for instant display.',
        );
      }
    } catch (error) {
      // Failure logging and retries are managed within TieredAdQueue. However,
      // no ad is coming from THIS task. Settle the oldest registered lease
      // waiter with null so it renders its empty state instantly instead of
      // hanging until its timeout (e.g. AdMob NO_FILL returning in ~200ms).
      final waiters = _leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)];
      if (waiters != null && waiters.isNotEmpty) {
        final waiter = waiters.removeFirst();
        if (waiters.isEmpty) _leaseWaiters.remove((placementId: placement.id, bannerLayout: bannerLayout));
        if (!waiter.isCompleted) waiter.complete(null);
        _logger?.warning('[Pool] Ad load failed for "${placement.id}". Settling oldest lease waiter with null.');
      }
    }
  }

  /// Checks whether an ad is primed and ready in memory.
  bool isReady(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return false;

    final queue = _cache[(placementId: placement.id, bannerLayout: bannerLayout)];
    if (queue == null || queue.isEmpty) return false;

    bool evictedAny = false;
    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Pool] Ad for "${placement.id}" expired in memory. Evicting and refilling.');
      _evictEntry(stale, isStale: true);
      evictedAny = true;
    }

    if (queue.isEmpty) {
      _queue.notifyEvicted(placement.id, bannerLayout: bannerLayout);
      if (!placement.loadOnce) {
        preload(placement, bannerLayout: bannerLayout);
      }
      return false;
    }

    if (evictedAny && !placement.loadOnce) {
      preload(placement, bannerLayout: bannerLayout);
    }

    return true;
  }

  /// Checks whether [placement] is currently in-flight downloading.
  bool isLoading(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    return _queue.isLoading(placement.id, bannerLayout: bannerLayout);
  }

  /// Returns the current lifecycle state of [placement].
  AdPlacementState getState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    if (isReady(placement, bannerLayout: bannerLayout)) return AdPlacementState.ready;
    return _queue.getState(placement.id, bannerLayout: bannerLayout);
  }

  /// Observes state transitions for [placement].
  Stream<AdPlacementState> watchState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    return _queue.watchState(placement.id, bannerLayout: bannerLayout);
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  ///
  /// Returns `true` if the ad is ready in memory; `false` if failed, timed out, or user is premium.
  Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) async {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return false;
    if (isReady(placement, bannerLayout: bannerLayout)) return true;
    if (isConsumed(placement) && _queue.pendingTaskCount(placement.id, bannerLayout: bannerLayout) == 0) {
      return false;
    }
    if (getState(placement, bannerLayout: bannerLayout) == AdPlacementState.error) return false;

    // If not currently loading or ready, ensure it is primed:
    if (!isLoading(placement, bannerLayout: bannerLayout)) {
      preload(placement, bannerLayout: bannerLayout);
    }

    // ⚡ Dynamically promote priority so this placement preempts background tasks:
    _queue.promote(placement.id, AdPriority.immediate, bannerLayout: bannerLayout);

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

    // Loading may settle during the network lookup. Inspect current state and
    // subscribe without another await so a broadcast event cannot be missed.
    if (!_adsAllowed) return false;
    if (isReady(placement, bannerLayout: bannerLayout)) return true;
    if (getState(placement, bannerLayout: bannerLayout) != AdPlacementState.loading) return false;

    final settled = Completer<bool>();
    final subscription = watchState(placement, bannerLayout: bannerLayout).listen(
      (state) {
        if (settled.isCompleted || state == AdPlacementState.loading) return;
        settled.complete(state == AdPlacementState.ready && isReady(placement, bannerLayout: bannerLayout));
      },
      onDone: () {
        if (!settled.isCompleted) settled.complete(false);
      },
    );
    try {
      return await settled.future.timeout(effectiveTimeout, onTimeout: () => false);
    } catch (_) {
      return false;
    } finally {
      await subscription.cancel();
    }
  }

  /// Waits without reserving the display. Acquires presentation ownership only
  /// when ready; another ad may legitimately be on screen by then.
  Future<void> _settleSplashAndPresent(
    FullscreenPlacement placement, {
    VoidCallback? onDismissed,
    void Function(num amount, String type)? onRewardGranted,
    VoidCallback? onDisplayed,
  }) async {
    final ready = await waitFor(placement);
    _settlingPresentations.remove(placement.id);
    if (!ready || !_adsAllowed) {
      _logger?.warning('[Show] Splash placement "${placement.id}" failed or timed out. Continuing user flow.');
      _queue.cancel(placement.id);
      _markConsumed(placement);
      onDismissed?.call();
      return;
    }

    show(placement, onDisplayed: onDisplayed, onDismissed: onDismissed, onRewardGranted: onRewardGranted);
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
    if (!_adsAllowed) {
      _logger?.info('[Show] Ads unavailable. Bypassing ad display for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    if (isConsumed(placement) &&
        (_cache[(placementId: placement.id, bannerLayout: null)]?.isEmpty ?? true) &&
        !isLoading(placement)) {
      _logger?.info('[Show] Placement "${placement.id}" is consumed and unloaded. Skipping presentation.');
      onDismissed?.call();
      return;
    }

    if (_settlingPresentations.contains(placement.id) || _mutex.isLocked) {
      _logger?.warning('[Show] Presentation lock active. Dropping show request for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    final queue = _cache[(placementId: placement.id, bannerLayout: null)];
    final cached = (queue != null && queue.isNotEmpty) ? queue.removeFirst() : null;
    if (cached != null && queue != null && queue.isEmpty && !placement.loadOnce) {
      _queue.notifyEvicted(placement.id);
    }

    if (cached == null || cached.isStale) {
      if (cached != null && cached.isStale) {
        _evictEntry(cached, isStale: true);
      }

      if (placement.isSplash && isLoading(placement)) {
        _settlingPresentations.add(placement.id);
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
        return;
      }

      _logger?.info('[Show] 0ms Cache Miss for "${placement.id}". Continuing user flow without delay.');
      if (placement.loadOnce) {
        _queue.cancel(placement.id);
        _markConsumed(placement);
      } else if (!placement.isSplash) {
        preload(placement);
      }
      onDismissed?.call();
      return;
    }

    _logger?.info('[Show] 🎯 0ms Cache Hit for "${placement.id}". Displaying ad.');
    final token = _mutex.tryAcquire(placement.id);
    if (token == null) {
      queue!.addFirst(cached);
      onDismissed?.call();
      return;
    }
    _markConsumed(placement);
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      _mutex.release(token);
      onDismissed?.call();
      if (!placement.loadOnce && _adsAllowed) {
        preload(placement);
      }
    }

    try {
      _driver.showFullscreenAd(
        placement: placement,
        adInstance: cached.adInstance,
        onDisplayed: () {
          if (!finished && _adsAllowed) onDisplayed?.call();
        },
        onDismissed: finish,
        onRewardGranted: onRewardGranted,
      );
    } catch (error, stack) {
      if (finished) rethrow;
      _logger?.error('[Show] Presentation failed for "${placement.id}".', error, stack);
      _evictEntry(cached);
      finish();
    }
  }

  /// Retrieves and exclusively consumes a cached inline ad (Banner/Native), refilling if recurring.
  ///
  /// Guarantees that the returned ad object is exclusively owned by the caller.
  ///
  /// If the buffer is empty, registers demand and completes when a replenished
  /// ad arrives (each waiter receives its own distinct instance), or returns
  /// `null` after [timeout] elapses without settlement.
  Future<dynamic> leaseInlineAd(InlinePlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) async {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return null;
    if (bannerLayout != null) _preferredBannerLayouts[placement.id] = bannerLayout;

    final queue = _cache.putIfAbsent((
      placementId: placement.id,
      bannerLayout: bannerLayout,
    ), () => ListQueue<AdCacheEntry>());

    // Evict any stale ads from the head of the buffer
    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Pool] Evicting stale inline ad for "${placement.id}".');
      _evictEntry(stale, isStale: true);
    }

    // 🚀 Exclusive Destructive Pop: No other widget can receive this ad object!
    final entry = queue.isNotEmpty ? queue.removeFirst() : null;

    if (entry != null) {
      if (queue.isEmpty && !placement.loadOnce) {
        _queue.notifyEvicted(placement.id, bannerLayout: bannerLayout);
      }
      if (placement.loadOnce) {
        _markConsumed(placement, bannerLayout: bannerLayout);
      } else {
        _logger?.info('[Pool] Auto-replenishing recurring inline placement "${placement.id}".');
        preload(placement, bannerLayout: bannerLayout);
      }
      return entry.adInstance;
    }

    // Buffer empty: register demand and let the pool deliver on arrival.
    // Promote to immediate so a user-visible ad never queues behind
    // low-priority background preloads.
    _queue.promote(placement.id, AdPriority.immediate, bannerLayout: bannerLayout);

    final waiter = Completer<dynamic>();
    _leaseWaiters
        .putIfAbsent((placementId: placement.id, bannerLayout: bannerLayout), () => ListQueue<Completer<dynamic>>())
        .addLast(waiter);
    _load(placement, forInlineDemand: true, bannerLayout: bannerLayout);

    final effectiveTimeout =
        timeout ??
        _timeoutConfig.resolve(
          format: placement.format,
          network: await _networkInfo.getNetworkType(),
          isSplash: placement.isSplash,
        );

    return waiter.future.timeout(
      effectiveTimeout,
      onTimeout: () {
        _leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)]?.remove(waiter);
        if (_leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)]?.isEmpty ?? false) {
          _leaseWaiters.remove((placementId: placement.id, bannerLayout: bannerLayout));
        }
        if (placement.loadOnce && !_leaseWaiters.containsKey((placementId: placement.id, bannerLayout: bannerLayout))) {
          _queue.cancel(placement.id, bannerLayout: bannerLayout);
          _markConsumed(placement, bannerLayout: bannerLayout);
        }
        _logger?.warning('[Pool] Inline lease for "${placement.id}" timed out. Returning null.');
        return null;
      },
    );
  }

  /// Schedules a microtask-level buffer replenishment without blocking the
  /// current caller. No-ops when the buffer+pending already meet target.
  void _scheduleReplenish(AdPlacement placement, {BannerLayout? bannerLayout}) {
    scheduleMicrotask(() {
      if (bannerLayout != null && _preferredBannerLayouts[placement.id] != bannerLayout) return;
      if (_closed || (_leaseWaiters[(placementId: placement.id, bannerLayout: bannerLayout)]?.isNotEmpty ?? false)) {
        // Waiters get priority; the load triggered by their lease already ran.
        return;
      }
      _load(placement, bannerLayout: bannerLayout, background: true);
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
