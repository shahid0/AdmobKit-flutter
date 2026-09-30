import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';

/// Interactive diagnostic screen demonstrating real-time placement states,
/// reactive state streams (`watchState`), deterministic settlement (`waitFor`),
/// and on-demand preloading across the entire registered ad catalog.
class PlacementStateMonitorScreen extends StatefulWidget {
  const PlacementStateMonitorScreen({super.key});

  @override
  State<PlacementStateMonitorScreen> createState() => _PlacementStateMonitorScreenState();
}

class _PlacementStateMonitorScreenState extends State<PlacementStateMonitorScreen> {
  final Map<String, String> _lastActions = {};

  Future<void> _testWaitFor(AdPlacement placement) async {
    final sw = Stopwatch()..start();
    setState(() => _lastActions[placement.id] = 'Waiting (5s max)...');
    final ready = await AdmobKit.waitFor(placement, timeout: const Duration(seconds: 5));
    sw.stop();
    if (!mounted) return;
    setState(() {
      _lastActions[placement.id] = 'waitFor: ${ready ? "SUCCESS" : "TIMEOUT/FAIL"} (${sw.elapsedMilliseconds}ms)';
    });
    TaskStore.instance.appendLog(
      '⏳ [waitFor] ${placement.id} -> result: $ready in ${sw.elapsedMilliseconds}ms',
    );
  }

  Future<void> _testPreload(AdPlacement placement) async {
    setState(() => _lastActions[placement.id] = 'Preload dispatched...');
    await AdmobKit.preload(placement);
    if (!mounted) return;
    setState(() => _lastActions[placement.id] = 'Preload completed');
    TaskStore.instance.appendLog('⚡ [Preload] Explicit preload triggered for ${placement.id}');
  }

  void _testShow(FullscreenPlacement placement) {
    TaskStore.instance.appendLog('🎬 [Show Test] Invoking 0ms show contract on ${placement.id}');
    AdmobKit.show(
      placement,
      onDisplayed: () {
        TaskStore.instance.appendLog('📺 [Show Test] ${placement.id} displayed on screen');
      },
      onDismissed: () {
        TaskStore.instance.appendLog('✅ [Show Test] ${placement.id} dismissed without blocking UX');
      },
      onRewardGranted: (amount, type) {
        TaskStore.instance.appendLog('🎁 [Show Test] Reward granted: $amount $type');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      appBar: AppBar(
        title: const Text('Placement State Monitor'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildGlobalStatusHeader(),
            const SizedBox(height: 16),
            const Text(
              'REGISTERED INVENTORY PLACEMENTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: TaskColors.textMutedCaption,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            ...SampleAds.allPlacements.map((placement) => _buildPlacementCard(placement)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStatusHeader() {
    return ValueListenableBuilder<AdInitializationState>(
      valueListenable: AdmobKit.initializationStateListenable,
      builder: (context, state, _) {
        return TaskCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStateBadge(state),
                  const Spacer(),
                  StatusBadge.slate(
                    'MUTEX: ${AdmobKit.isShowingAd ? "LOCKED" : "FREE"}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Engine State Machine & Pool Watcher',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: TaskColors.textInkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'canRequestAds: ${AdmobKit.canRequestAds} · isUserPremium: ${AdmobKit.isUserPremium}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: TaskColors.textSlateMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStateBadge(AdInitializationState state) {
    switch (state) {
      case AdInitializationState.ready:
        return StatusBadge.emerald('SDK READY');
      case AdInitializationState.initializingSdk:
      case AdInitializationState.gatheringConsent:
      case AdInitializationState.updatingConsent:
        return StatusBadge.amber('INITIALIZING');
      case AdInitializationState.failed:
      case AdInitializationState.consentDenied:
        return StatusBadge.rose('INIT FAILED');
      case AdInitializationState.disposed:
      case AdInitializationState.uninitialized:
        return StatusBadge.slate('IDLE');
    }
  }

  Widget _buildPlacementCard(AdPlacement placement) {
    final lastAction = _lastActions[placement.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TaskCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: TaskColors.accentSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    placement.format.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TaskColors.accentPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    placement.id,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TaskColors.textInkPrimary,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StreamBuilder<AdPlacementState>(
                  stream: AdmobKit.watchState(placement),
                  initialData: AdmobKit.getState(placement),
                  builder: (context, snapshot) {
                    final pState = snapshot.data ?? AdPlacementState.unloaded;
                    return _buildPlacementStateBadge(pState);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Priority: ${placement.priority.name} · LoadOnce: ${placement.loadOnce} · Splash: ${placement.isSplash}',
              style: const TextStyle(
                fontSize: 11,
                color: TaskColors.textMutedCaption,
                fontFamily: 'monospace',
              ),
            ),
            if (lastAction != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TaskColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lastAction,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                    color: TaskColors.textSlateMedium,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _testWaitFor(placement),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: TaskColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('waitFor(5s)', style: TextStyle(fontSize: 12, color: TaskColors.textInkPrimary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _testPreload(placement),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: TaskColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Preload', style: TextStyle(fontSize: 12, color: TaskColors.textInkPrimary)),
                  ),
                ),
                if (placement is FullscreenPlacement) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _testShow(placement),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TaskColors.accentPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('0ms Show', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementStateBadge(AdPlacementState state) {
    switch (state) {
      case AdPlacementState.ready:
        return StatusBadge.emerald('READY');
      case AdPlacementState.loading:
        return StatusBadge.amber('LOADING');
      case AdPlacementState.error:
        return StatusBadge.rose('ERROR');
      case AdPlacementState.unloaded:
        return StatusBadge.slate('UNLOADED');
    }
  }
}
