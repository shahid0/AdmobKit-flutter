import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  Timer? _navTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // 1. Pause App Open ads during Splash to prevent collisions
    FlutterAds.pauseAppOpen();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // 2. Schedule navigation after splash intro
    _navTimer = Timer(const Duration(milliseconds: 3000), _proceedToNextScreen);
  }

  void _proceedToNextScreen() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Splash priority handshake: If Splash Interstitial is ready, present it!
    if (FlutterAds.isReady(SampleAds.splashInterstitial)) {
      TaskStore.instance.appendLog('🚀 [Splash] Presenting primed Splash Interstitial ad...');
      FlutterAds.show(
        SampleAds.splashInterstitial,
        onDismissed: _navigateToOnboarding,
      );
    } else {
      TaskStore.instance.appendLog('⚡ [Splash] Splash Interstitial not primed yet. Proceeding immediately (0ms wait).');
      _navigateToOnboarding();
    }
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
    _navTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TaskFlow Pro',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart Orchestration & Focus',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Splash Inline Ad: Immediate-Display Priority Handshake
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Text(
                    'INITIALIZING PRODUCTION ENGINE...',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AdBannerView(
                    placement: SampleAds.splashBanner,
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
