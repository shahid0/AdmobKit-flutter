import 'package:flutter/material.dart';

import '../../domain/ad_placements.dart';
import '../admob_kit_facade.dart';

/// Full-coverage paywall guard intercepting system/hardware back gestures (`PopScope`)
/// and routing exits through a guarded full-screen ad placement.
///
/// Ensures free-tier users cannot bypass exit monetization via Android hardware back
/// buttons or edge swipe navigation, while seamlessly passing through for premium/VIP users.
class AdPaywallGuard extends StatefulWidget {
  /// The static paywall screen content widget.
  final Widget? child;

  /// A builder callback providing the [BuildContext] and a manual dismiss trigger.
  ///
  /// Pass `triggerDismiss` to custom close/cancel buttons in your paywall UI.
  final Widget Function(BuildContext context, VoidCallback triggerDismiss)? builder;

  /// The full-screen placement (typically an [InterstitialPlacement]) shown on exit.
  final FullscreenPlacement placement;

  /// Invoked when the paywall should complete dismissal.
  final VoidCallback onDismiss;

  /// Whether a purchase or restore has completed successfully, bypassing all exit ad logic.
  final bool isPurchased;

  /// Creates an [AdPaywallGuard] wrapping either a [child] widget or a [builder].
  const AdPaywallGuard({
    super.key,
    this.child,
    this.builder,
    required this.placement,
    required this.onDismiss,
    this.isPurchased = false,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided.');

  @override
  State<AdPaywallGuard> createState() => _AdPaywallGuardState();
}

class _AdPaywallGuardState extends State<AdPaywallGuard> {
  // Repeated taps or back presses while the exit ad opens must not dismiss twice.
  bool _exiting = false;

  void _handleExit() {
    if (_exiting) return;
    _exiting = true;
    if (widget.isPurchased || AdmobKit.isUserPremium) {
      widget.onDismiss();
      return;
    }
    AdmobKit.show(widget.placement, onDismissed: widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.builder != null ? widget.builder!(context, _handleExit) : widget.child!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: body,
    );
  }
}
