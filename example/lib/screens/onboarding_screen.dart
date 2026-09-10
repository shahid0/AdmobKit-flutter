import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../theme/task_theme.dart';
import 'paywall_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPaywall() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PaywallScreen(isFromOnboarding: true)),
    );
  }

  void _onContinueOrStart() {
    if (_currentPage < 2) {
      final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnimations) {
        _pageController.jumpToPage(_currentPage + 1);
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      _navigateToPaywall();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TaskColors.canvasGround,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildPageIndicator(),
            const SizedBox(height: 20),
            _buildBottomCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.topRight,
        child: TactileButton(
          onTap: _navigateToPaywall,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: TaskColors.textSlateMedium,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const StatusBadge(
            label: 'STAGE 01 • ARCHITECTURE',
            textColor: TaskColors.accentPrimary,
            surfaceColor: TaskColors.surfaceSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
          const SizedBox(height: 16),
          const Text(
            'Engineered for Focus',
            style: TextStyle(
              color: TaskColors.textInkPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'A deliberate system designed to eliminate digital fatigue and align daily execution with macro objectives.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TaskColors.textSlateMedium,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          TaskCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Q3 System Architecture Review',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TaskColors.textInkPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge.slate('High Priority'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TaskCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'AdMob Mediation Layer Audit',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: TaskColors.textInkPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge.slate('0ms Mutex'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const StatusBadge(
            label: 'STAGE 02 • WORKSPACES',
            textColor: TaskColors.accentPrimary,
            surfaceColor: TaskColors.surfaceSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unified Project Workspaces',
            style: TextStyle(
              color: TaskColors.textInkPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Categorize initiatives, isolate deep work sessions, and track execution velocity across multiple domains.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TaskColors.textSlateMedium,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          TaskCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SPONSORED RECOMMENDATION',
                  style: TextStyle(
                    color: TaskColors.textMutedCaption,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                AdNativeView(
                  placement: SampleAds.onboardingBigNative,
                  template: NativeAdTemplate.big,
                  placeholder: Container(
                    height: NativeAdTemplate.big.height,
                    width: NativeAdTemplate.big.width,
                    decoration: BoxDecoration(
                      color: TaskColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TaskColors.borderSubtle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const StatusBadge(
            label: 'STAGE 03 • MOMENTUM',
            textColor: TaskColors.accentPrimary,
            surfaceColor: TaskColors.surfaceSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
          const SizedBox(height: 16),
          const Text(
            'Unbroken Daily Momentum',
            style: TextStyle(
              color: TaskColors.textInkPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Transform sporadic bursts into resilient systems with integrated Pomodoro blocks and velocity analytics.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: TaskColors.textSlateMedium,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TaskCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '94.2%',
                        style: TextStyle(
                          color: TaskColors.textInkPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Consistency Rate',
                        style: TextStyle(
                          color: TaskColors.textSlateMedium,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TaskCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '18 Days',
                        style: TextStyle(
                          color: TaskColors.textInkPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Current Streak',
                        style: TextStyle(
                          color: TaskColors.textSlateMedium,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isSelected = _currentPage == index;

        return Container(
          width: 28,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          alignment: Alignment.center,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: isSelected ? 2.5 : 1.0),
            duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            builder: (context, scaleX, child) {
              return Transform.scale(
                scaleX: scaleX,
                scaleY: 1.0,
                child: child,
              );
            },
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.4,
              duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? TaskColors.accentPrimary : TaskColors.borderStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: TactileButton(
        onTap: _onContinueOrStart,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: TaskColors.accentPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: _currentPage == 2
              ? const Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                )
              : const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
