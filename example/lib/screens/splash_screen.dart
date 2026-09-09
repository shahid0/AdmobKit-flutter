import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final Animation<double> _heroFadeAnim;
  late final Animation<double> _heroScaleAnim;

  late final AnimationController _beaconController;
  late final Animation<double> _beaconAnim;

  Timer? _navTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // 1. Pause App Open ads during Splash to prevent collisions
    FlutterAds.pauseAppOpen();

    // 2. Composited Mount animation for Hero Monogram: 600ms ease-out
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFadeAnim = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOut,
    );
    _heroScaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _heroController,
        curve: Curves.easeOut,
      ),
    );
    _heroController.forward();

    // 3. Ambient Telemetry Beacon pulsing animation: 1200ms ease-in-out
    _beaconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _beaconAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _beaconController,
        curve: Curves.easeInOut,
      ),
    );
    _beaconController.repeat(reverse: true);

    // 4. Start responsive splash loading sequence (min 2.5s brand intro, max 4.5s ad readiness window)
    _startSplashSequence();
  }

  void _startSplashSequence() {
    const minSplashDuration = Duration(milliseconds: 2500);
    const maxSplashDuration = Duration(milliseconds: 4500);
    const pollInterval = Duration(milliseconds: 150);

    final startTime = DateTime.now();

    _navTimer = Timer.periodic(pollInterval, (timer) {
      if (!mounted || _hasNavigated) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startTime);
      final hasReachedMinTime = elapsed >= minSplashDuration;
      final hasReachedMaxTime = elapsed >= maxSplashDuration;

      final isInterstitialReady = FlutterAds.isReady(SampleAds.splashInterstitial);
      final isAppOpenReady = FlutterAds.isReady(SampleAds.appOpen);

      if (hasReachedMaxTime || (hasReachedMinTime && (isInterstitialReady || isAppOpenReady))) {
        timer.cancel();
        _proceedToNextScreen();
      }
    });
  }

  void _proceedToNextScreen() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Transition beacon to static emerald as per State Matrix
    _beaconController.stop();
    _beaconController.value = 1.0;

    // Splash presentation: prefer splash interstitial, fallback to primed app open
    final FullscreenPlacement candidate = FlutterAds.isReady(SampleAds.splashInterstitial)
        ? SampleAds.splashInterstitial
        : (FlutterAds.isReady(SampleAds.appOpen)
            ? SampleAds.appOpen
            : SampleAds.splashInterstitial);

    TaskStore.instance.appendLog(
      '🚀 [Splash] Presenting ${candidate.id} (${candidate.format.name}) with 0ms contract...',
    );
    FlutterAds.show(
      candidate,
      onDismissed: _navigateToOnboarding,
    );
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
    FlutterAds.resumeAppOpen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, _, _) => const OnboardingScreen(),
        transitionsBuilder: (context, anim, _, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    FlutterAds.resumeAppOpen();
    _heroController.dispose();
    _beaconController.dispose();
    super.dispose();
  }

  Widget _buildHeroBrand({required bool reduceMotion}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Monogram: 20px radius, accentPrimary, white icon, subtle border
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: TaskColors.accentPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: TaskColors.accentPrimary.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.token_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'TaskFlow Pro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: TaskColors.textInkPrimary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Architectural Clarity for High-Agency Builders',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
            color: TaskColors.textSlateMedium,
            height: 1.4,
          ),
        ),
      ],
    );

    if (reduceMotion) {
      return content;
    }

    return FadeTransition(
      opacity: _heroFadeAnim,
      child: ScaleTransition(
        scale: _heroScaleAnim,
        child: content,
      ),
    );
  }

  Widget _buildBeacon({required bool reduceMotion}) {
    final beaconDot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: TaskColors.emeraldText,
        shape: BoxShape.circle,
      ),
    );

    if (reduceMotion) {
      return beaconDot;
    }

    return FadeTransition(
      opacity: _beaconAnim,
      child: beaconDot,
    );
  }

  Widget _buildStatusTelemetry({required bool reduceMotion}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TaskColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TaskColors.borderSubtle),
        boxShadow: TaskColors.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBeacon(reduceMotion: reduceMotion),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'INITIALIZING PRODUCTION ENGINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: TaskColors.textSlateMedium,
                  fontFamily: 'monospace',
                ),
              ),
              SizedBox(height: 2),
              Text(
                'v2.4.0 • 0ms Mutex Ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: TaskColors.textInkPrimary,
                  fontFamily: 'monospace',
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAdContainer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: TaskColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TaskColors.borderSubtle),
          boxShadow: TaskColors.cardShadow,
        ),
        child: const AdNativeView(
          placement: SampleAds.splashBigNative,
          height: 280,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHeroBrand(reduceMotion: reduceMotion),
              const SizedBox(height: 20),
              _buildStatusTelemetry(reduceMotion: reduceMotion),
              const SizedBox(height: 24),
              _buildBottomAdContainer(),
            ],
          ),
        ),
      ),
    );
  }
}
