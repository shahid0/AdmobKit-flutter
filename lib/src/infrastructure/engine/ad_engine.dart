import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show LoadAdError;

import '../../domain/ad_network.dart';
import '../../domain/ad_placements.dart';
import '../../domain/ad_telemetry.dart';
import '../drivers/google_mobile_ads_driver.dart';
import '../logging/platform_ad_logger.dart';
import '../mutex/presentation_mutex.dart';
import 'ad_cache_entry.dart';
import 'retry_scheduler.dart';

/// Exception thrown when an in-flight or queued ad task is cancelled.
class AdTaskCancelledException implements Exception {
  final String placementId;
  const AdTaskCancelledException(this.placementId);

  @override
  String toString() => 'AdTaskCancelledException: Task for placement "$placementId" was cancelled.';
}

AdRequestKey _requestKey(AdPlacement placement, BannerLayout? bannerLayout) => (
  placementId: placement.id,
  bannerLayout: bannerLayout,
  collapsible: placement is BannerPlacement ? placement.collapsible : null,
);

/// A load task representing an ad placement awaiting download.
class AdLoadTask {
  final String key;
  final AdPlacement placement;
  final BannerLayout? bannerLayout;
  AdRequestKey get requestKey => _requestKey(placement, bannerLayout);
  final AdPriority priority;
  final int retryAttempt;
  final Completer<dynamic> completer;
  final DateTime createdAt;
  bool isCancelled;

  AdLoadTask({
    String? key,
    required this.placement,
    this.bannerLayout,
    required this.priority,
    this.retryAttempt = 0,
    Completer<dynamic>? completer,
    DateTime? createdAt,
    this.isCancelled = false,
  }) : key = key ?? placement.id,
       completer = completer ?? Completer<dynamic>(),
       createdAt = createdAt ?? DateTime.now();

  AdLoadTask copyWith({String? key, int? retryAttempt, AdPriority? priority, bool? isCancelled}) {
    return AdLoadTask(
      key: key ?? this.key,
      placement: placement,
      bannerLayout: bannerLayout,
      priority: priority ?? this.priority,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      completer: completer,
      createdAt: createdAt,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

class _LeaseWaiter {
  final Completer<dynamic> completer;
  final bool Function()? isMounted;
  _LeaseWaiter({required this.completer, this.isMounted});

  bool get isActive => isMounted == null || isMounted!();
}

/// Unified ad engine coordinating eager preloading, priority-tiered queuing,
/// concurrency gating, network-adaptive timeouts, in-memory buffering,
/// exclusive inline leases, and 0ms fullscreen presentations.
class AdEngine {
  final GoogleMobileAdsDriver? _driver;
  final Future<dynamic> Function(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest})?
  _executor;
  final PresentationMutex _mutex;
  final AdNetworkInfo _networkInfo;
  final AdTimeoutConfig _timeoutConfig;
  final RetryScheduler _retryScheduler;
  final PlatformAdLogger? _logger;
  final AdAnalyticsTracker? _analytics;
  final AdDiagnosticsTracker? _diagnostics;
  final bool Function()? _isPremium;
  final bool Function()? _canRequestAds;
  final Duration _adTtl;

  final int initialConcurrency;
  final int subsequentConcurrency;
  final Map<String, int> _placementCapacities;
  final Map<String, AdPlacement> _placements = {};
  final Map<String, BannerLayout> _preferredBannerLayouts = {};
  final Set<String> _consumedLoadOnceIds;
  final Set<String> _settlingPresentations = {};

  final Map<AdRequestKey, ListQueue<AdCacheEntry>> _cache = {};
  final Map<AdRequestKey, ListQueue<_LeaseWaiter>> _leaseWaiters = {};
  final Map<AdPriority, ListQueue<AdLoadTask>> _buckets = {
    AdPriority.splash: ListQueue<AdLoadTask>(),
    AdPriority.immediate: ListQueue<AdLoadTask>(),
    AdPriority.high: ListQueue<AdLoadTask>(),
    AdPriority.medium: ListQueue<AdLoadTask>(),
    AdPriority.low: ListQueue<AdLoadTask>(),
  };
  final Set<AdLoadTask> _inFlightTasks = {};
  final Map<String, ({Timer timer, AdLoadTask task})> _retries = {};

  final Map<AdRequestKey, AdPlacementState> _placementStates = {};
  final StreamController<({AdRequestKey requestKey, AdPlacementState state})> _stateController =
      StreamController<({AdRequestKey requestKey, AdPlacementState state})>.broadcast();

  final Set<String> _pendingInitialPlacementIds = {};
  bool _isInitialBatchActive = false;
  int _consecutiveCellularTimeouts = 0;
  bool _isPaused = false;
  bool _closed = false;
  bool _isDispatchScheduled = false;
  int _inlineSlotSequence = 0;
  StreamSubscription<AdNetworkType>? _networkSub;

  AdEngine({
    Set<String>? consumedLoadOnceIds,
    GoogleMobileAdsDriver? driver,
    Future<dynamic> Function(AdPlacement placement, {BannerLayout? bannerLayout, void Function()? validateRequest})?
    executor,
    PresentationMutex? mutex,
    required AdNetworkInfo networkInfo,
    AdTimeoutConfig? timeoutConfig,
    RetryScheduler? retryScheduler,
    PlatformAdLogger? logger,
    AdAnalyticsTracker? analytics,
    AdDiagnosticsTracker? diagnostics,
    bool Function()? isPremium,
    bool Function()? canRequestAds,
    Duration adTtl = const Duration(minutes: 50),
    this.initialConcurrency = 1,
    this.subsequentConcurrency = 1,
    Map<String, int>? placementCapacities,
  }) : _consumedLoadOnceIds = consumedLoadOnceIds ?? {},
       _driver = driver,
       _executor = executor,
       _mutex = mutex ?? PresentationMutex(),
       _networkInfo = networkInfo,
       _timeoutConfig = timeoutConfig ?? AdTimeoutConfig.standard,
       _retryScheduler = retryScheduler ?? RetryScheduler(),
       _logger = logger,
       _analytics = analytics,
       _diagnostics = diagnostics,
       _isPremium = isPremium,
       _canRequestAds = canRequestAds,
       _adTtl = adTtl,
       _placementCapacities = _validateCapacities(placementCapacities) {
    if (_driver == null && _executor == null) {
      throw ArgumentError('AdEngine requires either a GoogleMobileAdsDriver or an executor callback.');
    }
    _listenToNetworkChanges();
  }

  static Map<String, int> _validateCapacities(Map<String, int>? capacities) {
    final result = Map<String, int>.of(capacities ?? const {});
    for (final capacity in result.values) {
      if (capacity <= 0) throw ArgumentError.value(capacity, 'capacity', 'Must be positive');
    }
    return result;
  }

  void _listenToNetworkChanges() {
    _networkSub = _networkInfo.onNetworkTypeChanged.listen((network) {
      if (network == AdNetworkType.none) {
        _logger?.warning('[Engine] Network lost. Pausing ad dispatcher.');
        _isPaused = true;
      } else {
        if (_isPaused) {
          _logger?.info('[Engine] Network restored ($network). Resuming dispatcher.');
          _isPaused = false;
          _dispatchNext();
        }
      }
    });
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

  /// A placement ID has one immutable configuration during this engine lifetime.
  void validatePlacement(AdPlacement placement) {
    if (placement is BannerPlacement) placement.validate();
    final previous = _placements[placement.id];
    if (previous != null &&
        (previous.runtimeType != placement.runtimeType ||
            previous.androidId != placement.androidId ||
            previous.iosId != placement.iosId ||
            previous.loadOnce != placement.loadOnce ||
            previous.isSplash != placement.isSplash ||
            previous.priority != placement.priority ||
            (previous is BannerPlacement &&
                placement is BannerPlacement &&
                (previous.sizing != placement.sizing || previous.collapsible != placement.collapsible)) ||
            (previous is NativePlacement &&
                placement is NativePlacement &&
                (previous.template != placement.template || previous.style != placement.style)))) {
      throw ArgumentError('Conflicting configuration for placement "${placement.id}". Use a distinct placement ID.');
    }
    _placements[placement.id] = placement;
  }

  void _validateRequest(AdPlacement placement, BannerLayout? layout) {
    validatePlacement(placement);
    if (placement is BannerPlacement && placement.sizing.isAdaptive) {
      if (layout == null) throw ArgumentError('Adaptive banner requests require a BannerLayout.');
      layout.validate();
    } else if (layout != null) {
      throw ArgumentError('BannerLayout is only valid for adaptive banner placements.');
    }
  }

  void _makeBannerCacheRoom(String placementId) {
    final entries = _cache.entries.where((entry) => entry.key.placementId == placementId);
    while (entries.fold<int>(0, (total, entry) => total + entry.value.length) >= getCapacity(placementId)) {
      final oldest = entries
          .where((entry) => entry.value.isNotEmpty)
          .reduce((a, b) => a.value.first.loadedAt.isBefore(b.value.first.loadedAt) ? a : b);
      _evictEntry(oldest.value.removeFirst());
      _updateStateAfterEviction(placementId, bannerLayout: oldest.key.bannerLayout);
    }
  }

  /// Whether background preloading has stopped for this loadOnce placement.
  bool isConsumed(AdPlacement placement) =>
      placement.loadOnce && _consumedLoadOnceIds.contains(placement.id);

  void _markConsumed(AdPlacement placement, {BannerLayout? bannerLayout}) {
    if (!placement.loadOnce) return;
    _consumedLoadOnceIds.add(placement.id);
    _updateStateAfterEviction(placement.id, bannerLayout: bannerLayout);
  }

  /// Returns the underlying presentation mutex.
  PresentationMutex get mutex => _mutex;

  Duration get adTtl => _adTtl;

  /// Marks a collection of placement IDs as belonging to the initial preloading batch.
  void markInitialBatch(Iterable<String> placementIds) {
    _pendingInitialPlacementIds.addAll(placementIds);
    _isInitialBatchActive = _pendingInitialPlacementIds.isNotEmpty;
  }

  /// Whether the initial preloading batch is still in-flight or pending.
  bool get isInitialBatchActive => _isInitialBatchActive;

  /// The active concurrency limit based on whether the initial startup batch is running.
  int get activeConcurrency => _isInitialBatchActive ? initialConcurrency : subsequentConcurrency;

  /// Total number of pending tasks across all priority tiers.
  int get totalPending => _buckets.values.fold(0, (sum, q) => sum + q.length);

  /// Number of tasks for [placementId] that are queued, in-flight, or retrying.
  int pendingTaskCount(String placementId, {BannerLayout? bannerLayout, bool allLayouts = false}) {
    final queued = _buckets.values.fold<int>(
      0,
      (sum, q) =>
          sum + q.where((t) => t.placement.id == placementId && (allLayouts || t.bannerLayout == bannerLayout)).length,
    );
    final inFlight = _inFlightTasks
        .where((t) => t.placement.id == placementId && (allLayouts || t.bannerLayout == bannerLayout) && !t.isCancelled)
        .length;
    final retrying = _retries.values
        .where(
          (retry) => retry.task.placement.id == placementId && (allLayouts || retry.task.bannerLayout == bannerLayout),
        )
        .length;
    return queued + inFlight + retrying;
  }

  /// Primes placements at app startup according to their priority tiers.
  void primeAll(Iterable<AdPlacement> placements) {
    for (final placement in placements) {
      validatePlacement(placement);
    }
    if (!_adsAllowed) {
      _logger?.info('[Engine] Ads unavailable. Skipping initial ad preloading.');
      return;
    }

    // Adaptive banners need a measured host, so they load when their view mounts.
    final sorted = placements
        .where((placement) => !(placement is BannerPlacement && placement.sizing.isAdaptive) && !isConsumed(placement))
        .toList()
      ..sort((a, b) => a.priority.rank.compareTo(b.priority.rank));
    markInitialBatch(sorted.map((placement) => placement.id));
    _logger?.info('[Engine] 🚀 Priming startup queue with ${sorted.length} placement(s)...');

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
      _logger?.info('[Engine] Placement "${placement.id}" is loadOnce: true and already consumed. Preload skipped.');
      return;
    }

    final queue = _cache.putIfAbsent(_requestKey(placement, bannerLayout), () => ListQueue<AdCacheEntry>());

    queue.removeWhere((entry) {
      if (entry.isStale) {
        _logger?.info('[Engine] Evicting stale ad for "${placement.id}" (Age: ${entry.age.inMinutes}m).');
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
      if (totalBuffered + pendingTaskCount(placement.id, allLayouts: true) >= getCapacity(placement.id)) return;
    }
    final pending = pendingTaskCount(placement.id, bannerLayout: bannerLayout);
    final openLeases = _leaseWaiters[_requestKey(placement, bannerLayout)]?.where((w) => w.isActive).length ?? 0;
    final targetCapacity = getCapacity(placement.id);
    final effectiveCapacity = placement.loadOnce
        ? (forInlineDemand && openLeases > targetCapacity ? openLeases : targetCapacity)
        : targetCapacity + openLeases;
    if (buffered + pending >= effectiveCapacity) {
      _logger?.debug(
        '[Engine] Placement "${placement.id}" saturated '
        '(buffered:$buffered pending:$pending leases:$openLeases target:$effectiveCapacity).',
      );
      return;
    }

    _analytics?.onAdRequested(placement);
    final stopwatch = Stopwatch()..start();

    try {
      final adInstance = await enqueue(
        placement,
        bannerLayout: bannerLayout,
        overridePriority: forInlineDemand ? AdPriority.immediate : null,
      );
      if (!_adsAllowed) {
        AdCacheEntry.disposeAdInstance(adInstance);
        _updateStateAfterEviction(placement.id, bannerLayout: bannerLayout);
        throw AdTaskCancelledException(placement.id);
      }

      stopwatch.stop();
      _analytics?.onAdLoaded(placement, stopwatch.elapsed);

      // Demand-based delivery: serve active lease waiters on a LIFO basis
      final waiters = _leaseWaiters[_requestKey(placement, bannerLayout)];
      while (waiters != null && waiters.isNotEmpty) {
        final waiter = waiters.removeLast();
        if (waiters.isEmpty) _leaseWaiters.remove(_requestKey(placement, bannerLayout));
        if (waiter.completer.isCompleted) continue;
        if (!waiter.isActive) {
          _logger?.info('[Engine] Skipping unmounted lease waiter for "${placement.id}".');
          waiter.completer.complete(null);
          continue;
        }
        waiter.completer.complete(adInstance);
        if (placement.loadOnce) {
          _markConsumed(placement, bannerLayout: bannerLayout);
        } else {
          _updateStateAfterEviction(placement.id, bannerLayout: bannerLayout);
        }
        _logger?.info('[Engine] Delivered ad for "${placement.id}" directly to a waiting lease.');

        if (!placement.loadOnce && !isUserPremium) {
          _scheduleReplenish(placement, bannerLayout: bannerLayout);
        }
        return;
      }

      if (placement is BannerPlacement) _makeBannerCacheRoom(placement.id);
      queue.addLast(AdCacheEntry(placement: placement, adInstance: adInstance, ttl: _adTtl));
      _updateState(_requestKey(placement, bannerLayout), AdPlacementState.ready);
      _logger?.info(
        '[Engine] Buffer filled for "${placement.id}" (${queue.length}/$targetCapacity). Ready for instant display.',
      );
    } catch (error) {
      stopwatch.stop();
      if (error is! AdTaskCancelledException && !_closed) {
        int? errorCode;
        String errorMessage = error.toString();
        if (error is LoadAdError) {
          errorCode = error.code;
          errorMessage = error.message.isNotEmpty ? error.message : error.toString();
        } else if (error is TimeoutException) {
          errorMessage = error.message ?? 'Ad load timed out';
        }
        _analytics?.onAdFailedToLoad(placement, errorMessage, errorCode);
      }

      final pending = pendingTaskCount(placement.id, bannerLayout: bannerLayout);
      if (pending == 0) {
        final waiters = _leaseWaiters[_requestKey(placement, bannerLayout)];
        while (waiters != null && waiters.isNotEmpty) {
          final waiter = waiters.removeFirst();
          if (!waiter.completer.isCompleted) waiter.completer.complete(null);
        }
        _leaseWaiters.remove(_requestKey(placement, bannerLayout));
        _logger?.warning('[Engine] Ad load failed terminally for "${placement.id}". Settling lease waiters with null.');
      }
    }
  }

  /// Enqueues an ad placement for loading with priority routing and deduplication.
  Future<dynamic> enqueue(AdPlacement placement, {AdPriority? overridePriority, BannerLayout? bannerLayout}) {
    if (_closed) {
      return Future<dynamic>.error(AdTaskCancelledException(placement.id));
    }
    final priority = overridePriority ?? placement.priority;
    final effectiveKey = jsonEncode([placement.id, placement is InlinePlacement ? ++_inlineSlotSequence : null]);

    if (placement is! InlinePlacement) {
      for (final task in _inFlightTasks) {
        if (task.key == effectiveKey && !task.isCancelled) {
          _logger?.debug('[Engine] Task "$effectiveKey" is already in-flight.');
          return task.completer.future;
        }
      }

      final retry = _retries[effectiveKey];
      if (retry != null) return retry.task.completer.future;

      for (final queue in _buckets.values) {
        for (final existing in queue) {
          if (existing.key == effectiveKey) {
            _logger?.debug('[Engine] Task "$effectiveKey" is already queued in ${existing.priority.name}.');
            return existing.completer.future;
          }
        }
      }
    }

    final task = AdLoadTask(key: effectiveKey, placement: placement, bannerLayout: bannerLayout, priority: priority);
    _buckets[priority]!.addLast(task);
    _updateState(_requestKey(placement, bannerLayout), AdPlacementState.loading);
    _logger?.info(
      '[Engine] Enqueued "$effectiveKey" (${placement.id}) in [${priority.name}] tier. Total pending: $totalPending',
    );

    _scheduleDispatch();
    return task.completer.future;
  }

  /// Elevates priority of any pending tasks matching [placementId] to [newPriority].
  void promote(String placementId, AdPriority newPriority, {BannerLayout? bannerLayout}) {
    bool scheduled = false;
    for (final entry in _buckets.entries) {
      final currentPriority = entry.key;
      if (currentPriority <= newPriority) continue;

      final queue = entry.value;
      final matching = queue.where((t) => t.placement.id == placementId && t.bannerLayout == bannerLayout).toList();
      for (final task in matching) {
        queue.remove(task);
        final elevated = task.copyWith(priority: newPriority);
        _buckets[newPriority]!.addFirst(elevated);
        scheduled = true;
        _logger?.info('[Engine] ⚡ Promoted "${task.key}" from ${currentPriority.name} to ${newPriority.name}');
      }
    }
    if (scheduled) {
      _scheduleDispatch();
    }
  }

  void _scheduleDispatch() {
    if (_isDispatchScheduled) return;
    _isDispatchScheduled = true;
    scheduleMicrotask(() {
      _isDispatchScheduled = false;
      _dispatchNext();
    });
  }

  AdLoadTask? _pollNextTask() {
    if (_buckets[AdPriority.splash]!.isNotEmpty) {
      final splashQueue = _buckets[AdPriority.splash]!;
      for (final task in splashQueue) {
        if (task.placement is InlinePlacement) {
          splashQueue.remove(task);
          return task;
        }
      }
      return splashQueue.removeFirst();
    }

    if (_buckets[AdPriority.immediate]!.isNotEmpty) {
      final immediateQueue = _buckets[AdPriority.immediate]!;
      for (final task in immediateQueue) {
        if (task.placement is InlinePlacement) {
          immediateQueue.remove(task);
          return task;
        }
      }
      return immediateQueue.removeFirst();
    }

    if (_buckets[AdPriority.high]!.isNotEmpty) {
      return _buckets[AdPriority.high]!.removeFirst();
    }

    if (_buckets[AdPriority.medium]!.isNotEmpty) {
      return _buckets[AdPriority.medium]!.removeFirst();
    }

    if (_buckets[AdPriority.low]!.isNotEmpty) {
      return _buckets[AdPriority.low]!.removeFirst();
    }

    return null;
  }

  void _dispatchNext() {
    if (_isPaused || _closed) return;

    while (_inFlightTasks.length < activeConcurrency) {
      final task = _pollNextTask();
      if (task == null) break;
      _runTask(task);
    }
  }

  Future<void> _runTask(AdLoadTask task) async {
    _inFlightTasks.add(task);
    final placement = task.placement;
    var network = AdNetworkType.unknown;
    var timeout = Duration.zero;
    final stopwatch = Stopwatch()..start();

    try {
      network = await _networkInfo.getNetworkType();
      if (_handleCancelledInFlightTask(task)) return;
      timeout = _timeoutConfig.resolve(format: placement.format, network: network, isSplash: placement.isSplash);

      _logger?.info(
        '[Engine] 🚀 Dispatching "${placement.id}" (Tier: ${task.priority.name}, '
        'Net: ${network.name}, Timeout: ${timeout.inSeconds}s, In-Flight: ${_inFlightTasks.length}/$activeConcurrency)',
      );

      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.requested,
          retryAttempt: task.retryAttempt,
          elapsed: Duration.zero,
          networkType: network.name,
        ),
      );

      var expired = false;
      final Future<dynamic> loadFuture;
      if (_executor != null) {
        loadFuture = _executor(
          placement,
          bannerLayout: task.bannerLayout,
          validateRequest: () {
            if (expired || task.isCancelled || _closed || !_adsAllowed) {
              throw AdTaskCancelledException(placement.id);
            }
          },
        );
      } else {
        if (!_adsAllowed) throw AdTaskCancelledException(placement.id);
        loadFuture = _driver!.loadAd(
          placement,
          bannerLayout: task.bannerLayout,
          validateRequest: () {
            if (expired || task.isCancelled || _closed || !_adsAllowed) {
              throw AdTaskCancelledException(placement.id);
            }
          },
        );
      }

      final adInstance = await loadFuture
          .then((ad) {
            if (expired) AdCacheEntry.disposeAdInstance(ad);
            return ad;
          })
          .timeout(
            timeout,
            onTimeout: () {
              expired = true;
              throw TimeoutException('Ad load timed out', timeout);
            },
          );
      stopwatch.stop();

      if (_handleCancelledInFlightTask(task, adInstance)) {
        _logger?.info(
          '[Engine] Task "${task.key}" for "${placement.id}" was cancelled. Discarding loaded ad instance.',
        );
        return;
      }

      _consecutiveCellularTimeouts = 0;
      _logger?.info('[Engine] ✅ Loaded "${placement.id}" in ${stopwatch.elapsedMilliseconds}ms.');

      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.loaded,
          retryAttempt: task.retryAttempt,
          elapsed: stopwatch.elapsed,
          networkType: network.name,
        ),
      );

      _inFlightTasks.remove(task);
      if (!task.completer.isCompleted) {
        task.completer.complete(adInstance);
      }
    } on TimeoutException catch (e) {
      stopwatch.stop();
      if (_handleCancelledInFlightTask(task)) return;

      _logger?.warning(
        '[Timeout] ⏱️ Placement "${placement.id}" timed out after ${timeout.inSeconds}s on ${network.name}.',
      );

      if (network.isCellular) {
        _consecutiveCellularTimeouts++;
        if (_consecutiveCellularTimeouts >= 2) {
          _logger?.warning(
            '[BlackHole] ⚠️ Suspected mobile data exhaustion / captive portal black-hole. '
            '$_consecutiveCellularTimeouts consecutive cellular timeouts detected.',
          );
          _diagnostics?.onDiagnosticReport(
            AdDiagnosticReport(
              placementId: placement.id,
              format: placement.format,
              eventType: AdDiagnosticEventType.blackHoleSuspected,
              retryAttempt: task.retryAttempt,
              elapsed: stopwatch.elapsed,
              networkType: network.name,
              metadata: {'consecutiveTimeouts': _consecutiveCellularTimeouts},
            ),
          );
        }
      }

      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.timeout,
          retryAttempt: task.retryAttempt,
          elapsed: stopwatch.elapsed,
          networkType: network.name,
        ),
      );

      _inFlightTasks.remove(task);
      _handleFailure(task, isTimeout: true, error: e);
    } catch (error) {
      stopwatch.stop();

      if (error is AdTaskCancelledException) {
        cancel(placement.id, bannerLayout: task.bannerLayout);
      }
      if (_handleCancelledInFlightTask(task)) return;

      int? errorCode;
      String? errorMessage;
      if (error is LoadAdError) {
        errorCode = error.code;
        errorMessage = error.message;
      }

      _logger?.warning('[Engine] ❌ Failed to load "${placement.id}": [$errorCode] ${errorMessage ?? error}');

      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.failedToLoad,
          retryAttempt: task.retryAttempt,
          elapsed: stopwatch.elapsed,
          admobErrorCode: errorCode,
          admobErrorMessage: errorMessage,
          networkType: network.name,
        ),
      );

      _inFlightTasks.remove(task);
      _handleFailure(task, errorCode: errorCode, error: error);
    }

    _cleanupInitialBatch(placement.id);
    _dispatchNext();
  }

  void _cleanupInitialBatch(String placementId) {
    if (_isInitialBatchActive) {
      _pendingInitialPlacementIds.remove(placementId);
      if (_pendingInitialPlacementIds.isEmpty) {
        _isInitialBatchActive = false;
        _logger?.info(
          '[Engine] Initial preloading batch complete. Switching to subsequent concurrency ($subsequentConcurrency).',
        );
      }
    }
  }

  void _handleFailure(AdLoadTask task, {int? errorCode, bool isTimeout = false, Object? error}) {
    final placement = task.placement;
    final bannerLayout = task.bannerLayout;

    if (_retryScheduler.shouldRetry(attempt: task.retryAttempt, errorCode: errorCode)) {
      final nextAttempt = task.retryAttempt + 1;
      final delay = _retryScheduler.calculateDelay(
        attempt: task.retryAttempt,
        errorCode: errorCode,
        isTimeout: isTimeout,
      );

      _logger?.info(
        '[Retry] 🔁 Scheduling retry #$nextAttempt for "${placement.id}" in '
        '${delay.inMilliseconds / 1000.0}s (backoff + jitter).',
      );

      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.retryScheduled,
          retryAttempt: nextAttempt,
          elapsed: Duration.zero,
          admobErrorCode: errorCode,
          networkType: 'unknown',
          metadata: {'delayMs': delay.inMilliseconds},
        ),
      );

      final retryKey = task.key;
      final retriedTask = task.copyWith(retryAttempt: nextAttempt);
      final timer = Timer(delay, () {
        _retries.remove(retryKey);
        if (_closed || retriedTask.isCancelled) return;
        _buckets[retriedTask.priority]!.addFirst(retriedTask);
        _updateState(_requestKey(placement, bannerLayout), AdPlacementState.loading);
        _dispatchNext();
      });
      _retries[retryKey] = (timer: timer, task: retriedTask);
    } else {
      _logger?.warning(
        '[CircuitBreaker] 🛑 Retry limit reached or fatal error for "${placement.id}". Aborting retries.',
      );
      _diagnostics?.onDiagnosticReport(
        AdDiagnosticReport(
          placementId: placement.id,
          format: placement.format,
          eventType: AdDiagnosticEventType.circuitBroken,
          retryAttempt: task.retryAttempt,
          elapsed: Duration.zero,
          admobErrorCode: errorCode,
          networkType: 'unknown',
        ),
      );

      _updateState(_requestKey(placement, bannerLayout), AdPlacementState.error);

      if (!task.completer.isCompleted) {
        task.completer.completeError(error ?? Exception('Ad load failed'));
      }
    }
  }

  /// Cancels all pending queued and retrying load tasks for [placementId],
  /// and marks in-flight tasks as cancelled so their loaded assets are immediately discarded.
  void cancel(String placementId, {BannerLayout? bannerLayout}) {
    final retryKeys = _retries.entries
        .where((entry) => entry.value.task.placement.id == placementId && entry.value.task.bannerLayout == bannerLayout)
        .map((entry) => entry.key)
        .toList();
    for (final key in retryKeys) {
      final retry = _retries.remove(key)!;
      retry.timer.cancel();
      _cancelTask(retry.task);
    }

    for (final queue in _buckets.values) {
      queue.removeWhere((task) {
        if (task.placement.id == placementId && task.bannerLayout == bannerLayout) {
          _cancelTask(task);
          return true;
        }
        return false;
      });
    }

    for (final task in _inFlightTasks) {
      if (task.placement.id == placementId && task.bannerLayout == bannerLayout) {
        _cancelTask(task);
      }
    }

    final requestKeys = _placementStates.keys
        .where((key) => key.placementId == placementId && key.bannerLayout == bannerLayout)
        .toList();
    for (final key in requestKeys) {
      _updateState(key, AdPlacementState.unloaded);
    }
    _cleanupInitialBatch(placementId);
    _logger?.info('[Engine] 🛑 Cancelled pending and retrying tasks for "$placementId".');
  }

  void _cancelTask(AdLoadTask task) {
    task.isCancelled = true;
    if (!task.completer.isCompleted) {
      task.completer.completeError(AdTaskCancelledException(task.placement.id));
    }
  }

  bool _handleCancelledInFlightTask(AdLoadTask task, [dynamic adInstance]) {
    if (!task.isCancelled) return false;
    _inFlightTasks.remove(task);
    if (adInstance != null) {
      AdCacheEntry.disposeAdInstance(adInstance);
    }
    if (!task.completer.isCompleted) {
      task.completer.completeError(AdTaskCancelledException(task.placement.id));
    }
    _cleanupInitialBatch(task.placement.id);
    _dispatchNext();
    return true;
  }

  void _updateState(AdRequestKey requestKey, AdPlacementState state) {
    if (_placementStates[requestKey] == state) return;
    _placementStates[requestKey] = state;
    if (!_stateController.isClosed) {
      _stateController.add((requestKey: requestKey, state: state));
    }
  }

  AdRequestKey _requestKeyForId(String placementId, BannerLayout? bannerLayout) => (
    placementId: placementId,
    bannerLayout: bannerLayout,
    collapsible: switch (_placements[placementId]) {
      BannerPlacement(:final collapsible) => collapsible,
      _ => null,
    },
  );

  void _updateStateAfterEviction(String placementId, {BannerLayout? bannerLayout}) {
    final key = _requestKeyForId(placementId, bannerLayout);
    final count = _cache[key]?.length ?? 0;
    if (count > 0) {
      _updateState(key, AdPlacementState.ready);
    } else if (pendingTaskCount(placementId, bannerLayout: bannerLayout) > 0) {
      _updateState(key, AdPlacementState.loading);
    } else {
      _updateState(key, AdPlacementState.unloaded);
    }
  }

  /// Checks whether an ad is primed and ready in memory.
  bool isReady(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return false;

    final queue = _cache[_requestKey(placement, bannerLayout)];
    if (queue == null || queue.isEmpty) return false;

    bool evictedAny = false;
    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Engine] Ad for "${placement.id}" expired in memory. Evicting and refilling.');
      _evictEntry(stale, isStale: true);
      evictedAny = true;
    }

    if (queue.isEmpty) {
      _updateStateAfterEviction(placement.id, bannerLayout: bannerLayout);
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

  /// Checks whether [placement] is currently in-flight downloading or queued.
  bool isLoading(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    return pendingTaskCount(placement.id, bannerLayout: bannerLayout) > 0;
  }

  /// Checks whether [placementId] is currently in-flight downloading or queued.
  bool isLoadingById(String placementId, {BannerLayout? bannerLayout}) {
    return pendingTaskCount(placementId, bannerLayout: bannerLayout) > 0;
  }

  /// Returns the current lifecycle state of [placement].
  AdPlacementState getState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    if (isReady(placement, bannerLayout: bannerLayout)) return AdPlacementState.ready;
    return _placementStates[_requestKey(placement, bannerLayout)] ??
        (pendingTaskCount(placement.id, bannerLayout: bannerLayout) > 0
            ? AdPlacementState.loading
            : AdPlacementState.unloaded);
  }

  /// Returns the current lifecycle state for [placementId].
  AdPlacementState getStateById(String placementId, {BannerLayout? bannerLayout}) {
    final key = _requestKeyForId(placementId, bannerLayout);
    final queue = _cache[key];
    if (queue != null && queue.isNotEmpty && !queue.first.isStale) {
      return AdPlacementState.ready;
    }
    return _placementStates[key] ??
        (pendingTaskCount(placementId, bannerLayout: bannerLayout) > 0
            ? AdPlacementState.loading
            : AdPlacementState.unloaded);
  }

  /// Observes state transitions for [placement].
  Stream<AdPlacementState> watchState(AdPlacement placement, {BannerLayout? bannerLayout}) {
    _validateRequest(placement, bannerLayout);
    return _stateController.stream
        .where((e) => e.requestKey == _requestKey(placement, bannerLayout))
        .map((e) => e.state);
  }

  /// Observes state transitions for [placementId].
  Stream<AdPlacementState> watchStateById(String placementId, {BannerLayout? bannerLayout}) {
    return _stateController.stream
        .where((e) => e.requestKey.placementId == placementId && e.requestKey.bannerLayout == bannerLayout)
        .map((e) => e.state);
  }

  /// Deterministically awaits [placement] until it is ready, fails, or times out.
  Future<bool> waitFor(AdPlacement placement, {Duration? timeout, BannerLayout? bannerLayout}) async {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return false;
    if (isReady(placement, bannerLayout: bannerLayout)) return true;
    if (isConsumed(placement) && pendingTaskCount(placement.id, bannerLayout: bannerLayout) == 0) {
      return false;
    }
    if (getState(placement, bannerLayout: bannerLayout) == AdPlacementState.error) return false;

    if (!isLoading(placement, bannerLayout: bannerLayout)) {
      preload(placement, bannerLayout: bannerLayout);
    }

    promote(placement.id, AdPriority.immediate, bannerLayout: bannerLayout);

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
      cancel(placement.id);
      _markConsumed(placement);
      onDismissed?.call();
      return;
    }

    show(placement, onDisplayed: onDisplayed, onDismissed: onDismissed, onRewardGranted: onRewardGranted);
  }

  /// Shows a full-screen ad following the 0ms Non-Blocking Dumb View Contract.
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

    if (isConsumed(placement) && (_cache[_requestKey(placement, null)]?.isEmpty ?? true) && !isLoading(placement)) {
      _logger?.info('[Show] Placement "${placement.id}" is consumed and unloaded. Skipping presentation.');
      onDismissed?.call();
      return;
    }

    if (_settlingPresentations.contains(placement.id) || _mutex.isLocked) {
      _logger?.warning('[Show] Presentation lock active. Dropping show request for "${placement.id}".');
      onDismissed?.call();
      return;
    }

    final queue = _cache[_requestKey(placement, null)];
    final cached = (queue != null && queue.isNotEmpty) ? queue.removeFirst() : null;
    if (cached != null && queue != null && queue.isEmpty && !placement.loadOnce) {
      _updateStateAfterEviction(placement.id);
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
        cancel(placement.id);
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
      if (_driver == null) {
        finish();
        return;
      }
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
  Future<dynamic> leaseInlineAd(
    InlinePlacement placement, {
    Duration? timeout,
    BannerLayout? bannerLayout,
    bool Function()? isMounted,
  }) async {
    _validateRequest(placement, bannerLayout);
    if (!_adsAllowed) return null;
    if (bannerLayout != null) _preferredBannerLayouts[placement.id] = bannerLayout;

    final queue = _cache.putIfAbsent(_requestKey(placement, bannerLayout), () => ListQueue<AdCacheEntry>());

    while (queue.isNotEmpty && queue.first.isStale) {
      final stale = queue.removeFirst();
      _logger?.info('[Engine] Evicting stale inline ad for "${placement.id}".');
      _evictEntry(stale, isStale: true);
    }

    final entry = queue.isNotEmpty ? queue.removeFirst() : null;

    if (entry != null) {
      if (queue.isEmpty && !placement.loadOnce) {
        _updateStateAfterEviction(placement.id, bannerLayout: bannerLayout);
      }
      if (placement.loadOnce) {
        _markConsumed(placement, bannerLayout: bannerLayout);
      } else {
        _logger?.info('[Engine] Auto-replenishing recurring inline placement "${placement.id}".');
        preload(placement, bannerLayout: bannerLayout);
      }
      return entry.adInstance;
    }

    promote(placement.id, AdPriority.immediate, bannerLayout: bannerLayout);

    final waiter = _LeaseWaiter(completer: Completer<dynamic>(), isMounted: isMounted);
    _leaseWaiters.putIfAbsent(_requestKey(placement, bannerLayout), () => ListQueue<_LeaseWaiter>()).addLast(waiter);
    _load(placement, forInlineDemand: true, bannerLayout: bannerLayout);

    if (timeout != null) {
      return waiter.completer.future.timeout(
        timeout,
        onTimeout: () {
          _leaseWaiters[_requestKey(placement, bannerLayout)]?.remove(waiter);
          if (_leaseWaiters[_requestKey(placement, bannerLayout)]?.isEmpty ?? false) {
            _leaseWaiters.remove(_requestKey(placement, bannerLayout));
          }
          if (placement.loadOnce && !_leaseWaiters.containsKey(_requestKey(placement, bannerLayout))) {
            cancel(placement.id, bannerLayout: bannerLayout);
            _markConsumed(placement, bannerLayout: bannerLayout);
          }
          _logger?.warning('[Engine] Inline lease for "${placement.id}" timed out. Returning null.');
          return null;
        },
      );
    }

    return waiter.completer.future;
  }

  void _scheduleReplenish(AdPlacement placement, {BannerLayout? bannerLayout}) {
    scheduleMicrotask(() {
      if (bannerLayout != null && _preferredBannerLayouts[placement.id] != bannerLayout) return;
      if (_closed || (_leaseWaiters[_requestKey(placement, bannerLayout)]?.any((w) => w.isActive) ?? false)) {
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
    if (_closed) return;
    _closed = true;
    final placementIds = {
      ..._inFlightTasks.map((task) => task.requestKey),
      ..._buckets.values.expand((tasks) => tasks).map((task) => task.requestKey),
      ..._retries.values.map((retry) => retry.task.requestKey),
    };
    for (final id in placementIds) {
      cancel(id.placementId, bannerLayout: id.bannerLayout);
    }
    _stateController.close();
    _networkSub?.cancel();

    for (final entry in _cache.values.expand((q) => q)) {
      entry.dispose();
    }
    _cache.clear();

    for (final waiters in _leaseWaiters.values) {
      for (final waiter in waiters) {
        if (!waiter.completer.isCompleted) waiter.completer.complete(null);
      }
    }
    _leaseWaiters.clear();
    _mutex.forceRelease();
  }
}
