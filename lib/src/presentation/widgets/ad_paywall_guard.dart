import 'package:flutter/material.dart';
import '../../domain/models/ad_placement.dart';
import '../flutter_ads_facade.dart';

/// Full-coverage paywall guard intercepting system/hardware back gestures (`PopScope`)
/// and routing exits through a guarded full-screen ad placement.
class AdPaywallGuard extends StatelessWidget {
  /// The paywall screen content.
  final Widget child;

  /// Full-screen placement (typically an [InterstitialPlacement]) shown on exit.
  final FullscreenPlacement placement;

  /// Invoked when the paywall should complete dismissal.
  final VoidCallback onDismiss;

  /// Set to true if a purchase or restore has completed successfully,
  /// bypassing all exit ad logic.
  final bool isPurchased;

  const AdPaywallGuard({
    super.key,
    required this.child,
    required this.placement,
    required this.onDismiss,
    this.isPurchased = false,
  });

  void _handleExit() {
    if (isPurchased || FlutterAds.isUserPremium) {
      onDismiss();
      return;
    }

    FlutterAds.show(
      placement,
      onDismissed: onDismiss,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: child,
    );
  }
}
