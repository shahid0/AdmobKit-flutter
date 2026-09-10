import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  static bool isSplashActive = true;

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

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    SplashScreen.isSplashActive = true;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSplashSequence();
      }
    });
  }

  void _startSplashSequence() {
    TaskStore.instance.appendLog(
      '🚀 [Splash] Awaiting settlement for ${SampleAds.splashInterstitial.id}...',
    );
    FlutterAds.show(
      SampleAds.splashInterstitial,
      onDismissed: _proceedToNextScreen,
    );
  }

  void _proceedToNextScreen() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    SplashScreen.isSplashActive = false;

    _beaconController.stop();
    _beaconController.value = 1.0;

    _navigateToOnboarding();
  }

  void _navigateToOnboarding() {
    if (!mounted) return;
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
    _heroController.dispose();
    _beaconController.dispose();
    super.dispose();
  }

  Widget _buildHeroBrand({required bool reduceMotion}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    return Container(
      decoration: BoxDecoration(
        color: TaskColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TaskColors.borderSubtle),
        boxShadow: TaskColors.cardShadow,
      ),
      child: const AdNativeView(
        placement: SampleAds.splashBigNative,
        template: NativeAdTemplate.big,
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
