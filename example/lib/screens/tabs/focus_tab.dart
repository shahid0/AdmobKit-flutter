import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';

class FocusTab extends StatefulWidget {
  const FocusTab({super.key});

  @override
  State<FocusTab> createState() => _FocusTabState();
}

class _FocusTabState extends State<FocusTab> with TickerProviderStateMixin {
  static const int _defaultSeconds = 25 * 60; // 25 minutes
  static const int _boosterSeconds = 45 * 60; // 45 minutes

  int _totalSeconds = _defaultSeconds;
  int _secondsRemaining = _defaultSeconds;
  Timer? _timer;
  bool _isRunning = false;
  bool _isBoosterActive = false;

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        TaskStore.instance.appendLog('⏱️ [Focus] Pomodoro session completed!');
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = _isBoosterActive ? _boosterSeconds : _defaultSeconds;
      _totalSeconds = _isBoosterActive ? _boosterSeconds : _defaultSeconds;
    });
    if (TaskStore.instance.checkInterval('focus_reset', interval: 3)) {
      TaskStore.instance.appendLog('⏱️ [Action] Focus reset threshold reached. Triggering Interstitial...');
      FlutterAds.show(
        SampleAds.mainInterstitial,
        onDismissed: () {},
      );
    }
  }

  void _unlockBooster() {
    TaskStore.instance.appendLog('🎁 [Focus] User requested AI Flow State Booster. Triggering Rewarded Interstitial...');
    FlutterAds.show(
      SampleAds.rewardedInterstitial,
      onRewardGranted: (amount, type) {
        TaskStore.instance.appendLog('🎉 [Focus] Reward granted: $amount $type. Flow State Booster unlocked!');
        if (!mounted) return;
        setState(() {
          _isBoosterActive = true;
          _totalSeconds = _boosterSeconds;
          _secondsRemaining = _boosterSeconds;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚡ AI Flow State Booster active! Extended to 45m session.'),
            backgroundColor: TaskColors.accentPrimary,
          ),
        );
      },
      onDismissed: () {
        TaskStore.instance.appendLog('✅ [Focus] Rewarded Interstitial dismissed.');
      },
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0 ? (_secondsRemaining / _totalSeconds) : 0.0;

    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Deep Work Engine',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: TaskColors.textInkPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Interval focus sessions calibrated for peak cognitive output.',
              style: TextStyle(
                fontSize: 13,
                color: TaskColors.textSlateMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Circular Countdown Card
            TaskCard(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              borderRadius: 20,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isBoosterActive ? TaskColors.amberSurface : TaskColors.accentSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isBoosterActive ? TaskColors.amberBorder : TaskColors.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'POMODORO BLOCK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: _isBoosterActive ? TaskColors.amberText : TaskColors.accentPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ring Meter
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 8,
                              backgroundColor: TaskColors.surfaceSubtle,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isBoosterActive ? TaskColors.amberText : TaskColors.accentPrimary,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isRunning || _secondsRemaining != _totalSeconds
                                    ? _formatTime(_secondsRemaining)
                                    : '25:00',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                  color: TaskColors.textInkPrimary,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isRunning
                                    ? 'Deep Focus Active'
                                    : (_secondsRemaining < _totalSeconds ? 'Session Paused' : 'Ready for Deep Work'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: TaskColors.textSlateMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isRunning)
                          TactileButton(
                            onTap: _startTimer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: TaskColors.accentPrimary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: TaskColors.cardShadow,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Start Focus Session',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          TactileButton(
                            onTap: _pauseTimer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: TaskColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TaskColors.borderSubtle),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pause_rounded, color: TaskColors.textInkPrimary, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Pause Session',
                                    style: TextStyle(
                                      color: TaskColors.textInkPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_secondsRemaining < _totalSeconds || _isRunning) ...[
                          const SizedBox(width: 12),
                          TactileButton(
                            onTap: _resetTimer,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: TaskColors.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TaskColors.borderSubtle),
                              ),
                              child: const Text(
                                'Reset Timer',
                                style: TextStyle(
                                  color: TaskColors.textSlateMedium,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Rewarded Booster Card
            TaskCard(
              padding: const EdgeInsets.all(18),
              borderRadius: 16,
              backgroundColor: _isBoosterActive ? TaskColors.amberSurface : TaskColors.surfaceCard,
              border: Border.all(
                color: _isBoosterActive ? TaskColors.amberBorder : TaskColors.borderSubtle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isBoosterActive
                              ? TaskColors.amberText.withValues(alpha: 0.15)
                              : TaskColors.accentSubtle,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _isBoosterActive ? 'BOOSTER ACTIVE' : 'REWARDED BOOST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _isBoosterActive ? TaskColors.amberText : TaskColors.accentPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isBoosterActive ? Icons.bolt_rounded : Icons.lock_clock_rounded,
                        color: _isBoosterActive ? TaskColors.amberText : TaskColors.accentPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'AI Flow State Booster',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: TaskColors.textInkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unlock extended 45-min flow state with AI ambient frequency audio.',
                    style: TextStyle(
                      fontSize: 13,
                      color: TaskColors.textSlateMedium,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isBoosterActive)
                    TactileButton(
                      onTap: _unlockBooster,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: TaskColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: TaskColors.borderStrong),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_collection_rounded, color: TaskColors.textInkPrimary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Unlock Booster (Free Ad)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: TaskColors.textInkPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: TaskColors.amberText.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Flow State Booster Active (+45m)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TaskColors.amberText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
