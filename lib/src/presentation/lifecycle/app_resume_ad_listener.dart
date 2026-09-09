import 'package:flutter/widgets.dart';
import '../../domain/models/ad_placement.dart';
import '../../infrastructure/logging/platform_ad_logger.dart';
import '../../infrastructure/pool/eager_ad_pool.dart';

/// Observes app lifecycle transitions and presents primed App Open ads on resume.
class AppResumeAdListener with WidgetsBindingObserver {
  final AppOpenPlacement placement;
  final EagerAdPool pool;
  final PlatformAdLogger? logger;
  final Duration cooldown;
  bool _isAttached = false;
  bool _isPaused = false;

  AppResumeAdListener({
    required this.placement,
    required this.pool,
    this.logger,
    this.cooldown = const Duration(seconds: 4),
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _handleAppResume() {
    // 1. Developer Pause Guard
    if (_isPaused) {
      logger?.debug('[Resume] App Open is paused. Skipping display.');
      return;
    }

    // 2. Premium Guard
    if (pool.isUserPremium) {
      logger?.debug('[Resume] User is premium. Skipping App Open ad.');
      return;
    }

    // 3. Presentation Lock Guard (Never show on top of an active ad!)
    if (pool.mutex.isLocked) {
      logger?.warning(
        '[Resume] Presentation lock is active ("${pool.mutex.currentHolderId}"). '
        'Suppressing App Open ad to prevent collision.',
      );
      return;
    }

    // 4. Post-Fullscreen-Ad Dismissal Guard
    // When an interstitial or rewarded ad closes, Android/iOS resumes the app.
    // We MUST suppress the App Open ad that would otherwise collide.
    if (pool.mutex.isResumingFromAd) {
      pool.mutex.consumeResumeFromAd();
      logger?.info(
        '[Resume] App resumed directly from a dismissed fullscreen ad. '
        'Suppressing App Open ad to prevent collision.',
      );
      return;
    }

    // 5. Cooldown Guard
    if (pool.mutex.isWithinCooldown(cooldown)) {
      logger?.info(
        '[Resume] Within post-ad dismissal cooldown window. '
        'Suppressing App Open ad.',
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
