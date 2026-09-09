import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../widgets/app_drawer_console.dart';
import '../paywall_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F14),
          appBar: AppBar(
            backgroundColor: const Color(0xFF14141A),
            title: const Text('Settings & Ad Controls', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // VIP Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: store.isPremium
                      ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                      : const LinearGradient(colors: [Color(0xFF1E1E28), Color(0xFF282836)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: store.isPremium
                      ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 16)]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      store.isPremium ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded,
                      color: store.isPremium ? Colors.black : Colors.white70,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.isPremium ? 'TaskFlow PRO Active' : 'Free Ad-Supported Tier',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: store.isPremium ? Colors.black : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            store.isPremium ? 'All ads suppressed globally' : 'Toggle below to test VIP bypass',
                            style: TextStyle(
                              fontSize: 12,
                              color: store.isPremium ? Colors.black87 : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: store.isPremium,
                      activeThumbColor: Colors.black,
                      activeTrackColor: Colors.white,
                      onChanged: (val) => store.togglePremium(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text('MONETIZATION & ADS VERIFICATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2)),
              const SizedBox(height: 10),

              // View Paywall Screen
              _buildActionTile(
                icon: Icons.payments_outlined,
                color: const Color(0xFF6366F1),
                title: 'View Paywall Screen',
                subtitle: 'Test paywall close guard & back press ad interception',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
              ),

              // Test Interstitial Ad (with lifecycle suppression check)
              _buildActionTile(
                icon: Icons.fullscreen_rounded,
                color: const Color(0xFF3B82F6),
                title: 'Test Interstitial Ad',
                subtitle: 'Verify that dismissing does NOT trigger an App Open ad',
                onTap: () {
                  store.appendLog('🎬 [Test] Triggering manual Interstitial ad...');
                  FlutterAds.show(
                    SampleAds.mainInterstitial,
                    onDismissed: () {
                      store.appendLog('✅ [Test] Interstitial dismissed. Verified: No App Open ad collision!');
                    },
                  );
                },
              ),

              // Watch Rewarded to Unlock Theme
              _buildActionTile(
                icon: Icons.palette_rounded,
                color: const Color(0xFFEC4899),
                title: 'Watch Ad: Unlock Cyberpunk Theme',
                subtitle: store.isProThemeUnlocked ? 'Theme Unlocked! (Reward Granted)' : 'Watch short video ad to unlock custom theme',
                trailing: store.isProThemeUnlocked ? const Icon(Icons.check_circle, color: Color(0xFF10B981)) : null,
                onTap: () {
                  if (store.isProThemeUnlocked) return;
                  FlutterAds.show(
                    SampleAds.rewardedBonus,
                    onDismissed: () {},
                    onRewardGranted: (amount, type) {
                      store.unlockProTheme();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎨 Cyberpunk theme unlocked!'), backgroundColor: Color(0xFFEC4899)),
                      );
                    },
                  );
                },
              ),

              // Test App Open Lifecycle controls
              _buildActionTile(
                icon: Icons.splitscreen_rounded,
                color: const Color(0xFF10B981),
                title: 'Show App Open Ad Directly',
                subtitle: 'Present primed App Open ad on demand',
                onTap: () {
                  store.appendLog('📱 [Test] Presenting App Open ad on demand...');
                  FlutterAds.show(
                    SampleAds.appOpen,
                    onDismissed: () {
                      store.appendLog('✅ [Test] App Open ad dismissed.');
                    },
                  );
                },
              ),

              // AdMob Inspector
              _buildActionTile(
                icon: Icons.bug_report_rounded,
                color: const Color(0xFFF59E0B),
                title: 'Open AdMob Inspector',
                subtitle: 'Validate adapters, SDK initialization, and test ads',
                onTap: () {
                  FlutterAds.openAdInspector((error) {
                    if (error != null) {
                      store.appendLog('❌ Inspector error: $error');
                    } else {
                      store.appendLog('🔍 AdMob Inspector opened.');
                    }
                  });
                },
              ),

              // UMP Privacy Options
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                color: const Color(0xFF8B5CF6),
                title: 'Privacy & GDPR Consent Options',
                subtitle: 'Present Google UMP consent form',
                onTap: () async {
                  final shown = await FlutterAds.showPrivacyOptionsForm();
                  store.appendLog('📋 [UMP] Privacy form shown result: $shown');
                },
              ),

              // Live Logs Console
              _buildActionTile(
                icon: Icons.terminal_rounded,
                color: const Color(0xFF06B6D4),
                title: 'Live Ad Console & Event Feed',
                subtitle: 'Inspect analytics impressions, revenue paid events & diagnostics',
                onTap: () => AppDrawerConsole.show(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
