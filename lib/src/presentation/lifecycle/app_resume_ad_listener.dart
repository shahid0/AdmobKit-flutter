import 'package:flutter/widgets.dart';
import '../../domain/models/ad_placement.dart';
import '../../infrastructure/logging/platform_ad_logger.dart';
import '../../infrastructure/pool/eager_ad_pool.dart';
import 'flutter_ads_route_observer.dart';

/// Observes app lifecycle transitions and presents primed App Open ads on resume.
class AppResumeAdListener with WidgetsBindingObserver {
  final AppOpenPlacement placement;
  final EagerAdPool pool;
  final PlatformAdLogger? logger;
  final FlutterAdsRouteObserver? routeObserver;
  bool _isAttached = false;
  bool _isPaused = false;
  bool _appWasBackgroundedBySystem = false;

  AppResumeAdListener({
    required this.placement,
    required this.pool,
    this.logger,
    this.routeObserver,
  });

  /// Attaches the lifecycle observer to [WidgetsBinding.instance].
  void attach() {
    if (!_isAttached) {
      WidgetsBinding.instance.addObserver(this);
      _isAttached = true;
      logger?.debug('[Resume] Attached AppResumeAdListener for "${placement.id}".');
    }
  }

  /// Detaches the lifecycle observer.
  void detach() {
    if (_isAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _isAttached = false;
      logger?.debug('[Resume] Detached AppResumeAdListener.');
    }
  }

  /// Temporarily pauses App Open ad triggers (e.g. during splash, paywall, camera).
  void pause() {
    _isPaused = true;
    logger?.debug('[Resume] App Open ads paused.');
  }

  /// Resumes App Open ad triggers.
  void resume() {
    _isPaused = false;
    logger?.debug('[Resume] App Open ads resumed.');
  }

  /// Whether App Open ads are currently paused.
  bool get isPaused => _isPaused;

  /// Visible for testing: whether the system background flag is currently armed.
  @visibleForTesting
  bool get isBackgroundArmed => _appWasBackgroundedBySystem;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Arms only if the transition to background occurred without an active full-screen ad
      if (!pool.mutex.isLocked) {
        _appWasBackgroundedBySystem = true;
        logger?.debug(
          '[Resume] App entered ${state.name} while free of fullscreen ads. Background flag armed.',
        );
      } else {
        logger?.debug(
          '[Resume] App entered ${state.name} while fullscreen ad "${pool.mutex.currentHolderId}" is active. '
          'Background flag NOT armed.',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _handleAppResume() {
    // 1. True Background Guard: Only trigger if the app genuinely went to background
    if (!_appWasBackgroundedBySystem) {
      logger?.debug(
        '[Resume] App resumed without prior system backgrounding (ad dismissal, modal transition, or boot). '
        'Suppressing App Open ad.',
      );
      return;
    }

    // Reset flag immediately to guarantee 1-to-1 consumption
    _appWasBackgroundedBySystem = false;

    // 2. Developer Pause Guard
    if (_isPaused) {
      logger?.debug('[Resume] App Open is paused. Skipping display.');
      return;
    }

    // 3. Premium Guard
    if (pool.isUserPremium) {
      logger?.debug('[Resume] User is premium. Skipping App Open ad.');
      return;
    }

    // 4. Presentation Lock Guard (Never show on top of an active ad!)
    if (pool.mutex.isLocked) {
      logger?.warning(
        '[Resume] Presentation lock is active ("${pool.mutex.currentHolderId}"). '
        'Suppressing App Open ad to prevent collision.',
      );
      return;
    }

    // 5. Route-Aware View Lifecycle Guard
    if (routeObserver != null && !routeObserver!.isResumeAdAllowed) {
      logger?.info(
        '[Resume] Active route "${routeObserver?.currentRouteName ?? 'modal'}" does not permit App Open ads. '
        'Suppressing to prevent flow disruption.',
      );
      return;
    }

    // 6. Buffer Readiness Check
    if (!pool.isReady(placement)) {
      logger?.info('[Resume] App Open ad not primed or expired on resume. Triggering preload.');
      pool.preload(placement);
      return;
    }

    logger?.info('[Resume] 📱 Presenting primed App Open ad on app resume.');
    pool.show(
      placement,
      onDismissed: () {
        logger?.debug('[Resume] App Open ad dismissed on resume.');
      },
    );
  }
}
