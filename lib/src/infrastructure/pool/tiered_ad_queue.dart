import 'dart:async';
import 'dart:collection';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_network_info.dart';
import '../../domain/models/ad_placement.dart';
import '../../domain/models/ad_placement_state.dart';
import '../../domain/models/ad_priority.dart';
import '../../domain/models/ad_timeout_config.dart';
import '../../domain/models/diagnostic_report.dart';
import '../logging/platform_ad_logger.dart';
import 'retry_scheduler.dart';

/// A load task representing an ad placement awaiting download.
class AdLoadTask {
  final AdPlacement placement;
  final AdPriority priority;
  final int retryAttempt;
  final Completer<dynamic> completer;
  final DateTime createdAt;

  AdLoadTask({
    required this.placement,
    required this.priority,
    this.retryAttempt = 0,
    Completer<dynamic>? completer,
    DateTime? createdAt,
  })  : completer = completer ?? Completer<dynamic>(),
        createdAt = createdAt ?? DateTime.now();

  AdLoadTask copyWith({
    int? retryAttempt,
    AdPriority? priority,
  }) {
    return AdLoadTask(
      placement: placement,
      priority: priority ?? this.priority,
      retryAttempt: retryAttempt ?? this.retryAttempt,
      completer: completer,
      createdAt: createdAt,
    );
  }
}

/// The 4-Tier FIFO Queue Dispatcher enforcing concurrency = 2,
/// network-adaptive timeouts, inline-first immediate priority, and black-hole defense.
class TieredAdQueue {
  final Future<dynamic> Function(AdPlacement placement) _executor;
  final AdNetworkInfo _networkInfo;
  final AdTimeoutConfig _timeoutConfig;
  final RetryScheduler _retryScheduler;
  final PlatformAdLogger? _logger;
  final AdDiagnosticsTracker? _diagnostics;

  // 5 Tier Buckets
  final Map<AdPriority, ListQueue<AdLoadTask>> _buckets = {
    AdPriority.splash: ListQueue<AdLoadTask>(),
    AdPriority.immediate: ListQueue<AdLoadTask>(),
    AdPriority.high: ListQueue<AdLoadTask>(),
    AdPriority.medium: ListQueue<AdLoadTask>(),
    AdPriority.low: ListQueue<AdLoadTask>(),
  };

  // State tracking per placement
  final Map<String, AdPlacementState> _placementStates = {};
  final StreamController<({String placementId, AdPlacementState state})> _stateController =
      StreamController<({String placementId, AdPlacementState state})>.broadcast();

  // Holding timers for tasks in exponential backoff
  final Map<String, Timer> _activeRetryTimers = {};

  /// Concurrency limit during initial app startup / initial placement preloading (defaults to 1).
  final int initialConcurrency;

  /// Concurrency limit for subsequent ad preloads and replenishments (defaults to 1).
  final int subsequentConcurrency;

  // Active in-flight tasks
  final Set<AdLoadTask> _inFlightTasks = {};

  // Initial batch tracking
  final Set<String> _pendingInitialPlacementIds = {};
  bool _isInitialBatchActive = false;

  /// Marks a collection of placement IDs as belonging to the initial preloading batch.
  void markInitialBatch(Iterable<String> placementIds) {
    _pendingInitialPlacementIds.addAll(placementIds);
    _isInitialBatchActive = _pendingInitialPlacementIds.isNotEmpty;
  }

  /// Whether the initial preloading batch is still in-flight or pending.
  bool get isInitialBatchActive => _isInitialBatchActive;

  /// The active concurrency limit based on whether the initial startup batch is running.
  int get activeConcurrency => _isInitialBatchActive ? initialConcurrency : subsequentConcurrency;

  // Telco TCP black-hole defense counter
  int _consecutiveCellularTimeouts = 0;

  bool _isPaused = false;
  StreamSubscription<AdNetworkType>? _networkSub;

  TieredAdQueue({
    required Future<dynamic> Function(AdPlacement placement) executor,
    required AdNetworkInfo networkInfo,
    AdTimeoutConfig? timeoutConfig,
    RetryScheduler? retryScheduler,
    PlatformAdLogger? logger,
    AdDiagnosticsTracker? diagnostics,
    this.initialConcurrency = 1,
    this.subsequentConcurrency = 1,
  })  : _executor = executor,
        _networkInfo = networkInfo,
        _timeoutConfig = timeoutConfig ?? AdTimeoutConfig.standard,
        _retryScheduler = retryScheduler ?? RetryScheduler(),
        _logger = logger,
        _diagnostics = diagnostics {
    _listenToNetworkChanges();
  }

  void _listenToNetworkChanges() {
    _networkSub = _networkInfo.onNetworkTypeChanged.listen((network) {
      if (network == AdNetworkType.none) {
        _logger?.warning('[Queue] Network lost. Pausing ad dispatcher.');
        _isPaused = true;
      } else {
        if (_isPaused) {
          _logger?.info('[Queue] Network restored ($network). Resuming dispatcher.');
          _isPaused = false;
          _dispatchNext();
        }
      }
    });
  }

  /// Enqueues an ad placement for loading with priority routing and deduplication.
  Future<dynamic> enqueue(AdPlacement placement, {AdPriority? overridePriority}) {
    final priority = overridePriority ?? placement.priority;

    // Avoid duplicate queuing if already in-flight or queued for the same placement
    for (final task in _inFlightTasks) {
      if (task.placement.id == placement.id) {
        _logger?.debug('[Queue] Placement "${placement.id}" is already in-flight.');
        return task.completer.future;
      }
    }

    for (final queue in _buckets.values) {
      for (final existing in queue) {
        if (existing.placement.id == placement.id) {
          _logger?.debug('[Queue] Placement "${placement.id}" is already queued in ${existing.priority.name}.');
          return existing.completer.future;
        }
      }
    }

    final task = AdLoadTask(
      placement: placement,
      priority: priority,
    );

    _buckets[priority]!.addLast(task);
    _updateState(placement.id, AdPlacementState.loading);
    _logger?.info('[Queue] Enqueued "${placement.id}" in [${priority.name}] tier. Total pending: $totalPending');

    _scheduleDispatch();
    return task.completer.future;
  }

  bool _isDispatchScheduled = false;

  void _scheduleDispatch() {
    if (_isDispatchScheduled) return;
    _isDispatchScheduled = true;
    scheduleMicrotask(() {
      _isDispatchScheduled = false;
      _dispatchNext();
    });
  }

  /// Total number of pending tasks across all tiers.
  int get totalPending => _buckets.values.fold(0, (sum, q) => sum + q.length);

  /// Returns the next eligible task across priority tiers.
  AdLoadTask? _pollNextTask() {
    // 1. Splash Tier (Highest Order: Cold Start / First Screen Placements)
    // The screen that acts as splash only has at most 1 inline (banner/native) and 1 fullscreen ad.
    // Inline loads before fullscreen, filling concurrency slots 1 & 2 concurrently at boot.
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

    // 2. Immediate Tier (Active visible screen / Onboarding placements)
    // Inline loads before fullscreen within immediate tier as well.
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

    // 2. High Tier
    if (_buckets[AdPriority.high]!.isNotEmpty) {
      return _buckets[AdPriority.high]!.removeFirst();
    }

    // 3. Medium Tier
    if (_buckets[AdPriority.medium]!.isNotEmpty) {
      return _buckets[AdPriority.medium]!.removeFirst();
    }

    // 4. Low Tier
    if (_buckets[AdPriority.low]!.isNotEmpty) {
      return _buckets[AdPriority.low]!.removeFirst();
    }

    return null;
  }

  void _updateState(String placementId, AdPlacementState state) {
    if (_placementStates[placementId] == state) return;
    _placementStates[placementId] = state;
    if (!_stateController.isClosed) {
      _stateController.add((placementId: placementId, state: state));
    }
  }

  /// Returns the current lifecycle state for [placementId].
  AdPlacementState getState(String placementId) {
    return _placementStates[placementId] ?? AdPlacementState.unloaded;
  }

  /// Returns true if [placementId] is currently in-flight downloading.
  bool isLoading(String placementId) {
    return getState(placementId) == AdPlacementState.loading;
  }

  /// Observes state transitions for [placementId].
  Stream<AdPlacementState> watchState(String placementId) {
    return _stateController.stream
        .where((e) => e.placementId == placementId)
        .map((e) => e.state);
  }

  /// Called when an ad is evicted or consumed from cache.
  void notifyEvicted(String placementId) {
    _updateState(placementId, AdPlacementState.unloaded);
  }

  /// Called when an ad is confirmed ready in cache.
  void notifyReady(String placementId) {
    _updateState(placementId, AdPlacementState.ready);
  }

  /// Dispatches pending tasks up to the concurrency limit.
  void _dispatchNext() {
    if (_isPaused) return;

    while (_inFlightTasks.length < activeConcurrency) {
      final task = _pollNextTask();
      if (task == null) break;
      _runTask(task);
    }
  }

  Future<void> _runTask(AdLoadTask task) async {
    _inFlightTasks.add(task);
    final placement = task.placement;
    final network = await _networkInfo.getNetworkType();
    final timeout = _timeoutConfig.resolve(
      format: placement.format,
      network: network,
      isSplash: placement.isSplash,
    );

    _logger?.info(
      '[Queue] 🚀 Dispatching "${placement.id}" (Tier: ${task.priority.name}, '
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

    final stopwatch = Stopwatch()..start();

    try {
      final adInstance = await _executor(placement).timeout(timeout);
      stopwatch.stop();

      _consecutiveCellularTimeouts = 0; // Reset black-hole detector on success
      _logger?.info(
        '[Queue] ✅ Loaded "${placement.id}" in ${stopwatch.elapsedMilliseconds}ms.',
      );

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
    } on TimeoutException {
      stopwatch.stop();
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
      _handleFailure(task, isTimeout: true);
    } catch (error) {
      stopwatch.stop();
      int? errorCode;
      String? errorMessage;

      if (error is LoadAdError) {
        errorCode = error.code;
        errorMessage = error.message;
      }

      _logger?.warning(
        '[Queue] ❌ Failed to load "${placement.id}": [$errorCode] ${errorMessage ?? error}',
      );

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

    // Track initial batch settlement
    if (_isInitialBatchActive) {
      _pendingInitialPlacementIds.remove(placement.id);
      if (_pendingInitialPlacementIds.isEmpty) {
        _isInitialBatchActive = false;
        _logger?.info(
          '[Queue] Initial preloading batch complete. Switching to subsequent concurrency ($subsequentConcurrency).',
        );
      }
    }

    // Continue queue execution
    _dispatchNext();
  }

  void _handleFailure(
    AdLoadTask task, {
    int? errorCode,
    bool isTimeout = false,
    Object? error,
  }) {
    final placement = task.placement;
    _updateState(placement.id, AdPlacementState.error);

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

      _activeRetryTimers[placement.id]?.cancel();
      _activeRetryTimers[placement.id] = Timer(delay, () {
        _activeRetryTimers.remove(placement.id);
        final retriedTask = task.copyWith(retryAttempt: nextAttempt);
        _buckets[task.priority]!.addFirst(retriedTask);
        _dispatchNext();
      });
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

      if (!task.completer.isCompleted) {
        task.completer.completeError(error ?? Exception('Ad load failed'));
      }
    }
  }

  /// Cancels all pending timers and subscriptions.
  void dispose() {
    _stateController.close();
    _networkSub?.cancel();
    for (final timer in _activeRetryTimers.values) {
      timer.cancel();
    }
    _activeRetryTimers.clear();
    for (final bucket in _buckets.values) {
      bucket.clear();
    }
    _inFlightTasks.clear();
  }
}
