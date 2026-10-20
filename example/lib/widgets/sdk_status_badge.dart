import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import '../theme/task_theme.dart';

/// Reactive SDK status badge listening to AdmobKit.initializationStateListenable.
class SdkStatusBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const SdkStatusBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdInitializationState>(
      valueListenable: AdmobKit.initializationStateListenable,
      builder: (context, state, _) {
        final badge = _buildBadge(state);
        if (onTap != null) {
          return TactileButton(onTap: onTap, child: badge);
        }
        return badge;
      },
    );
  }

  Widget _buildBadge(AdInitializationState state) {
    switch (state) {
      case AdInitializationState.ready:
        return StatusBadge.emerald(
          'SDK READY',
          icon: const Icon(Icons.bolt_rounded, size: 12, color: TaskColors.emeraldText),
        );
      case AdInitializationState.initializingSdk:
      case AdInitializationState.gatheringConsent:
      case AdInitializationState.updatingConsent:
        return StatusBadge.amber(
          'INIT...',
          icon: const Icon(Icons.sync_rounded, size: 12, color: TaskColors.amberText),
        );
      case AdInitializationState.failed:
      case AdInitializationState.consentDenied:
        return StatusBadge.rose(
          'INIT FAILED',
          icon: const Icon(Icons.error_outline_rounded, size: 12, color: TaskColors.roseText),
        );
      case AdInitializationState.disposed:
      case AdInitializationState.uninitialized:
        return StatusBadge.slate(
          'SDK IDLE',
          icon: const Icon(Icons.power_settings_new_rounded, size: 12, color: TaskColors.slateText),
        );
    }
  }
}
