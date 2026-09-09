import 'dart:async';
import 'dart:collection';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/contracts/ad_diagnostics_tracker.dart';
import '../../domain/contracts/ad_network_info.dart';
import '../../domain/models/ad_placement.dart';
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

/// The 4-Tier FIFO Queue Dispatcher enforcing concurrency = 1,
/// network-adaptive timeouts, splash priority handshakes, and black-hole defense.
class TieredAdQueue {
  final Future<dynamic> Function(AdPlacement placement) _executor;
  final AdNetworkInfo _networkInfo;
  final AdTimeoutConfig _timeoutConfig;
  final RetryScheduler _retryScheduler;
  final PlatformAdLogger? _logger;
  final AdDiagnosticsTracker? _diagnostics;

  // 4 Tier Buckets
  final Map<AdPriority, ListQueue<AdLoadTask>> _buckets = {
    AdPriority.immediate: ListQueue<AdLoadTask>(),
    AdPriority.splashFullscreen: ListQueue<AdLoadTask>(),
    AdPriority.high: ListQueue<AdLoadTask>(),
    AdPriority.medium: ListQueue<AdLoadTask>(),
    AdPriority.low: ListQueue<AdLoadTask>(),
  };

  // Holding timers for tasks in exponential backoff
  final Map<String, Timer> _activeRetryTimers = {};

  // Maximum concurrent in-flight ad downloads (Skill requirement: max 1-2)
  static const int maxConcurrency = 2;

  // Active in-flight tasks (Concurrency <= 2)
  final Set<AdLoadTask> _inFlightTasks = {};

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
    // Top Priority Pairing: If splash fullscreen task is pending and none is currently in-flight,
    // dispatch it concurrently with immediate splash inline to ensure both preload simultaneously.
    final hasInFlightSplashFullscreen = _inFlightTasks.any(
      (t) => t.priority == AdPriority.splashFullscreen,
    );
    if (!hasInFlightSplashFullscreen &&
        _buckets[AdPriority.splashFullscreen]!.isNotEmpty) {
      return _buckets[AdPriority.splashFullscreen]!.removeFirst();
    }

    // 1. Immediate Tier (Always first)
    if (_buckets[AdPriority.immediate]!.isNotEmpty) {
      return _buckets[AdPriority.immediate]!.removeFirst();
    }

    // 2. Splash Fullscreen Tier (Top priority alongside immediate splash inline)
    if (_buckets[AdPriority.splashFullscreen]!.isNotEmpty) {
      return _buckets[AdPriority.splashFullscreen]!.removeFirst();
    }

    // 3. High Tier
    if (_buckets[AdPriority.high]!.isNotEmpty) {
      return _buckets[AdPriority.high]!.removeFirst();
    }

    // 4. Medium Tier
    if (_buckets[AdPriority.medium]!.isNotEmpty) {
      return _buckets[AdPriority.medium]!.removeFirst();
    }

    // 5. Low Tier
    if (_buckets[AdPriority.low]!.isNotEmpty) {
      return _buckets[AdPriority.low]!.removeFirst();
    }

    return null;
  }

  /// Dispatches pending tasks up to the concurrency limit.
  void _dispatchNext() {
    if (_isPaused) return;

    while (_inFlightTasks.length < maxConcurrency) {
      final task = _pollNextTask();
      if (task == null) break;
      _runTask(task);
    }
  }

  Future<void> _runTask(AdLoadTask task) async {
    _inFlightTasks.add(task);
    final placement = task.placement;
    final network = await _networkInfo.getNetworkType();
    final timeout = _timeoutConfig.resolve(format: placement.format, network: network);

    _logger?.info(
      '[Queue] 🚀 Dispatching "${placement.id}" (Tier: ${task.priority.name}, '
      'Net: ${network.name}, Timeout: ${timeout.inSeconds}s, In-Flight: ${_inFlightTasks.length}/$maxConcurrency)',
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
