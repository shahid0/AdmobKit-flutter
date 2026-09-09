import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../../config/sample_ads.dart';
import '../../state/task_store.dart';
import '../../theme/task_theme.dart';
import '../../widgets/app_drawer_console.dart';
import '../paywall_screen.dart';

/// Architectural Light Theme settings and ad verification surface.
///
/// Implements `.uispec/specs/settings_tab.spec.md` and
/// `.uispec/content/settings_tab.slots.md`.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          body: ListView(
            cacheExtent: 1500,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 1. Header Section
              _buildHeader(),
              const SizedBox(height: 16),

              // 2. VIP Switcher Card
              _buildVipCard(store),
              const SizedBox(height: 24),

              // 3. Section Label
              _buildSectionHeader(),
              const SizedBox(height: 12),

              // 4. Seven Tool Action Tiles
              // Tile 1: View Paywall Screen
              _buildActionTile(
                icon: Icons.payments_outlined,
                title: 'View Paywall Screen',
                subtitleWidget: const Text(
                  'Test paywall close guard & back press ad interception',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
              ),

              // Tile 2: Test Interstitial Ad
              _buildActionTile(
                icon: Icons.fullscreen_rounded,
                title: 'Test Interstitial Ad',
                subtitleWidget: const Text(
                  'Verify that dismissing does NOT trigger an App Open ad',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
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

              // Tile 3: Watch Ad: Unlock Executive Theme
              _buildActionTile(
                icon: Icons.palette_outlined,
                title: 'Watch Ad: Unlock Executive Theme',
                subtitleWidget: store.isProThemeUnlocked
                    ? const Text(
                        'Theme Unlocked (Reward Granted)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: TaskColors.emeraldText,
                          height: 1.4,
                        ),
                      )
                    : const Text(
                        'Watch short video ad to unlock custom styling',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: TaskColors.textSlateMedium,
                          height: 1.4,
                        ),
                      ),
                trailing: store.isProThemeUnlocked
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: TaskColors.emeraldText,
                        size: 20,
                      )
                    : const Icon(
                        Icons.chevron_right_rounded,
                        color: TaskColors.textMutedCaption,
                        size: 20,
                      ),
                onTap: () {
                  if (store.isProThemeUnlocked) return;
                  FlutterAds.show(
                    SampleAds.rewardedBonus,
                    onDismissed: () {},
                    onRewardGranted: (amount, type) {
                      store.unlockProTheme();
                    },
                  );
                },
              ),

              // Tile 4: Show App Open Ad Directly
              _buildActionTile(
                icon: Icons.splitscreen_rounded,
                title: 'Show App Open Ad Directly',
                subtitleWidget: const Text(
                  'Present primed App Open ad on demand',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
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

              // Tile 5: Open AdMob Inspector
              _buildActionTile(
                icon: Icons.bug_report_outlined,
                title: 'Open AdMob Inspector',
                subtitleWidget: const Text(
                  'Validate adapters, SDK initialization, and test ads',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
                onTap: () {
                  store.appendLog('🔍 [Test] Opening AdMob Inspector...');
                  FlutterAds.openAdInspector((error) {
                    if (error != null) {
                      store.appendLog('❌ Inspector error: $error');
                    } else {
                      store.appendLog('🔍 AdMob Inspector opened.');
                    }
                  });
                },
              ),

              // Tile 6: Privacy & GDPR Consent Options
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy & GDPR Consent Options',
                subtitleWidget: const Text(
                  'Present Google UMP consent form',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
                onTap: () async {
                  store.appendLog('📋 [UMP] Requesting Privacy & GDPR consent form...');
                  final shown = await FlutterAds.showPrivacyOptionsForm();
                  store.appendLog('📋 [UMP] Privacy form shown result: $shown');
                },
              ),

              // Tile 7: Live Ad Console & Event Feed
              _buildActionTile(
                icon: Icons.terminal_rounded,
                title: 'Live Ad Console & Event Feed',
                subtitleWidget: const Text(
                  'Inspect analytics impressions, revenue paid events & diagnostics',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
                onTap: () => AppDrawerConsole.show(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings & Ad Controls',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: TaskColors.textInkPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Enterprise monetization diagnostics and subscription simulation.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: TaskColors.textSlateMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipCard(TaskStore store) {
    return TaskCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      backgroundColor:
          store.isPremium ? TaskColors.emeraldSurface : TaskColors.surfaceCard,
      border: Border.all(
        color: store.isPremium ? TaskColors.emeraldBorder : TaskColors.borderSubtle,
        width: 1,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: store.isPremium
                  ? TaskColors.surfaceCard
                  : TaskColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: store.isPremium
                    ? TaskColors.emeraldBorder
                    : TaskColors.borderSubtle,
              ),
            ),
            child: Icon(
              store.isPremium
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_outline_rounded,
              color: store.isPremium
                  ? TaskColors.emeraldText
                  : TaskColors.textSlateMedium,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.isPremium ? 'TaskFlow PRO Active' : 'Free Ad-Supported Tier',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: store.isPremium
                        ? TaskColors.emeraldText
                        : TaskColors.textInkPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  store.isPremium
                      ? 'All ads suppressed globally with zero latency.'
                      : 'Toggle switch to test instant VIP ad suppression.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: TaskColors.textSlateMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: store.isPremium,
            activeThumbColor: Colors.white,
            activeTrackColor: TaskColors.accentPrimary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: TaskColors.surfaceSubtle,
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? TaskColors.accentPrimary
                  : TaskColors.borderStrong,
            ),
            onChanged: (val) => store.togglePremium(val),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'MONETIZATION & ADS VERIFICATION',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 1.0,
          color: TaskColors.textMutedCaption,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Widget subtitleWidget,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TaskCard(
        borderRadius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        backgroundColor: TaskColors.surfaceCard,
        border: Border.all(color: TaskColors.borderSubtle),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: TaskColors.accentSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TaskColors.accentPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: Icon(icon, color: TaskColors.accentPrimary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: TaskColors.textInkPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  subtitleWidget,
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: TaskColors.textMutedCaption,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}
