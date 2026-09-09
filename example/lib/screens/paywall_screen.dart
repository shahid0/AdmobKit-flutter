import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';
import 'main_tabs_screen.dart';

enum PaywallTier { annual, monthly }

class PaywallScreen extends StatefulWidget {
  final bool isFromOnboarding;

  const PaywallScreen({
    super.key,
    this.isFromOnboarding = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PaywallTier _selectedTier = PaywallTier.annual;
  bool _isPurchased = false;

  void _dismissPaywall() {
    if (!mounted) return;
    if (widget.isFromOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainTabsScreen()),
      );
    } else {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        Navigator.of(context).removeRoute(route);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _onPurchaseSuccess() {
    setState(() {
      _isPurchased = true;
    });
    TaskStore.instance.togglePremium(true);
    _dismissPaywall();
  }

  @override
  Widget build(BuildContext context) {
    return AdPaywallGuard(
      placement: SampleAds.mainInterstitial,
      onDismiss: _dismissPaywall,
      isPurchased: _isPurchased,
      child: Scaffold(
        backgroundColor: TaskColors.canvasGround,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildHero(),
                      const SizedBox(height: 24),
                      _buildFeatures(),
                      const SizedBox(height: 20),
                      _buildTiers(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          const StatusBadge(
            label: 'LIMITED ACCESS',
            textColor: TaskColors.accentPrimary,
            surfaceColor: TaskColors.accentSubtle,
            borderColor: TaskColors.borderSubtle,
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: TaskColors.textSlateMedium,
                size: 22,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: TaskColors.accentSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TaskColors.borderSubtle),
            boxShadow: TaskColors.cardShadow,
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: TaskColors.accentPrimary,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'TaskFlow Pro VIP',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TaskColors.textInkPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Architectural focus without interruptions. Pure execution.',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: TaskColors.textSlateMedium,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures() {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.block_rounded,
          title: '100% Ad-Free Ecosystem',
          desc: 'Zero interstitials, banners, or video delays across all 15 workspaces.',
        ),
        const SizedBox(height: 10),
        _buildFeatureCard(
          icon: Icons.workspaces_outlined,
          title: 'Unlimited Deep Workspaces',
          desc: 'Structure unbounded project hierarchies with instant filtering.',
        ),
        const SizedBox(height: 10),
        _buildFeatureCard(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Automated Accomplishment Reports',
          desc: 'Instant one-tap PDF exports without watching rewarded ads.',
        ),
        const SizedBox(height: 10),
        _buildFeatureCard(
          icon: Icons.bolt_rounded,
          title: '0ms Priority Engine',
          desc: 'All executive features primed in memory with zero latency.',
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return TaskCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: TaskColors.emeraldSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TaskColors.emeraldBorder),
            ),
            child: Icon(icon, color: TaskColors.accentPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: TaskColors.textInkPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TaskColors.textSlateMedium,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTiers() {
    return Column(
      children: [
        _buildTierCard(
          tier: PaywallTier.annual,
          title: 'Annual Membership',
          price: '3-Day Free Trial, then \$29.99/year',
          badge: StatusBadge.emerald('SAVE 50%'),
        ),
        const SizedBox(height: 12),
        _buildTierCard(
          tier: PaywallTier.monthly,
          title: 'Monthly Membership',
          price: '\$4.99/month',
          badge: null,
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required PaywallTier tier,
    required String title,
    required String price,
    Widget? badge,
  }) {
    final isSelected = _selectedTier == tier;

    return _buildTactileWrapper(
      onTap: () => setState(() => _selectedTier = tier),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: TaskColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? TaskColors.accentPrimary : TaskColors.borderSubtle,
            width: 2,
          ),
          boxShadow: TaskColors.cardShadow,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? TaskColors.accentPrimary : TaskColors.borderStrong,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: TaskColors.textInkPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price,
                    style: const TextStyle(
                      color: TaskColors.textSlateMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            ?badge,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTactileWrapper(
            onTap: _onPurchaseSuccess,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: TaskColors.accentPrimary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Start 3-Day Free Trial',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No commitment. Cancel anytime in App Store or Google Play.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TaskColors.textMutedCaption,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTactileWrapper({
    required Widget child,
    required VoidCallback onTap,
  }) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
    }
    return TactileButton(
      onTap: onTap,
      child: child,
    );
  }
}
