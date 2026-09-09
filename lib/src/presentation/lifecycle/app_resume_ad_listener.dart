import 'package:flutter/widgets.dart';
import '../../domain/models/ad_placement.dart';
import '../../infrastructure/logging/platform_ad_logger.dart';
import '../../infrastructure/pool/eager_ad_pool.dart';

/// Observes app lifecycle transitions and presents primed App Open ads on resume.
class AppResumeAdListener with WidgetsBindingObserver {
  final AppOpenPlacement placement;
  final EagerAdPool pool;
  final PlatformAdLogger? logger;
  bool _isAttached = false;

  AppResumeAdListener({
    required this.placement,
    required this.pool,
    this.logger,
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  void _handleAppResume() {
    if (pool.isUserPremium) {
      logger?.debug('[Resume] User is premium. Skipping App Open ad.');
      return;
    }

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
