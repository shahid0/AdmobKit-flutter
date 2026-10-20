import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import '../../config/sample_ads.dart';
import '../../theme/task_theme.dart';

/// Demonstrates two simultaneous native ad widgets bound to the same placement ID
/// with zero AdWidget collision, made possible by placementCapacities: {'multi_widget_showcase': 2}.
class MultiWidgetShowcaseScreen extends StatelessWidget {
  const MultiWidgetShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      appBar: AppBar(title: const Text('Multi-Widget Capacities'), leading: const BackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            TaskCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge.emerald(
                        'CAPACITY: 2',
                        icon: const Icon(Icons.layers_rounded, size: 12, color: TaskColors.emeraldText),
                      ),
                      const Spacer(),
                      const StatusBadge(
                        label: 'ZERO COLLISION',
                        textColor: TaskColors.accentPrimary,
                        surfaceColor: TaskColors.accentSubtle,
                        borderColor: TaskColors.borderSubtle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Simultaneous Shared Placement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: TaskColors.textInkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Both native card slots below share the placement ID "multi_widget_showcase". The engine maintains independent buffer leases and distinct native ad view instances without runtime crashes.',
                    style: TextStyle(fontSize: 13, color: TaskColors.textSlateMedium, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: 'SLOT 1 · FIRST NATIVE HOST'),
            const SizedBox(height: 8),
            _NativeCardContainer(slotIndex: 1, child: AdNativeView(placement: SampleAds.multiWidgetNative)),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'SLOT 2 · SECOND NATIVE HOST'),
            const SizedBox(height: 8),
            _NativeCardContainer(slotIndex: 2, child: AdNativeView(placement: SampleAds.multiWidgetNative)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: TaskColors.textMutedCaption,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _NativeCardContainer extends StatelessWidget {
  final int slotIndex;
  final Widget child;

  const _NativeCardContainer({required this.slotIndex, required this.child});

  @override
  Widget build(BuildContext context) {
    return TaskCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: TaskColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: TaskColors.borderSubtle),
                  ),
                  child: Text(
                    'SPONSORED (SLOT $slotIndex)',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: TaskColors.textMutedCaption,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SampleAds.multiWidgetNative.template.name,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11, color: TaskColors.textSlateMedium, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
        ],
      ),
    );
  }
}
