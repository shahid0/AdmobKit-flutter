import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import 'main_tabs_screen.dart';

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
  void _dismissPaywall() {
    if (!mounted) return;
    if (widget.isFromOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainTabsScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onPurchaseSuccess() {
    // Rule: Completed purchase immediately dismisses the view without presenting any ad!
    TaskStore.instance.togglePremium(true);
    TaskStore.instance.appendLog('🎉 VIP Purchase completed! Ad-free mode active.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('👑 Welcome to TaskFlow Pro! All ads removed.'),
        backgroundColor: Color(0xFF6366F1),
      ),
    );
    _dismissPaywall();
  }

  @override
  Widget build(BuildContext context) {
    return AdPaywallGuard(
      placement: SampleAds.mainInterstitial,
      onDismiss: _dismissPaywall,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: SafeArea(
          child: Column(
            children: [
              // Top Close Button Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF6366F1)),
                      ),
                      child: const Text(
                        'LIMITED OFFER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF818CF8),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      tooltip: 'Close Paywall (Guarded by Ad)',
                      onPressed: () {
                        // Triggers the AdPaywallGuard close protocol
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ],
                ),
              ),

              // Hero Banner
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Upgrade to Pro',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Experience the cleanest, ad-free productivity workflow with high-velocity focus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Feature comparison
                      _buildFeatureRow(
                        icon: Icons.block_flipped,
                        title: '100% Ad-Free Experience',
                        subtitle: 'Zero banners, zero interstitials, zero waiting.',
                      ),
                      _buildFeatureRow(
                        icon: Icons.all_inclusive_rounded,
                        title: 'Unlimited Tasks & Projects',
                        subtitle: 'Organize unlimited personal and professional workflows.',
                      ),
                      _buildFeatureRow(
                        icon: Icons.palette_outlined,
                        title: 'Pro Dark & Cyberpunk Themes',
                        subtitle: 'Hand-crafted aesthetic themes for late night coding sessions.',
                      ),
                      _buildFeatureRow(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Instant PDF Productivity Export',
                        subtitle: 'Export weekly task accomplishment reports without ads.',
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Pricing & CTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B24),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF6366F1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF6366F1), size: 22),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Annual Pro Membership',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '3 days free trial, then \$29.99/year',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SAVE 50%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _onPurchaseSuccess,
                        child: const Text(
                          'Start 3-Day Free Trial',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No commitment. Cancel anytime in App Store or Google Play.',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF222230),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF818CF8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
