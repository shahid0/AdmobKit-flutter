import 'package:flutter/material.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';
import '../widgets/app_drawer_console.dart';
import 'tabs/tasks_list_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/focus_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/settings_tab.dart';
import '../widgets/sdk_status_badge.dart';
import 'ad_gallery_screen.dart';
import 'sub_screens/placement_state_monitor_screen.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    TasksListTab(),
    CategoriesTab(),
    FocusTab(),
    AnalyticsTab(),
    SettingsTab(),
  ];

  void _showSdkInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: TaskColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'AdmobKit Status & Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: TaskColors.textInkPrimary,
                  ),
                ),
                const Spacer(),
                const SdkStatusBadge(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'canRequestAds: ${AdmobKit.canRequestAds} · isShowingAd: ${AdmobKit.isShowingAd} · isUserPremium: ${AdmobKit.isUserPremium}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: TaskColors.textSlateMedium,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.speed_rounded, color: TaskColors.accentPrimary),
              title: const Text('Placement State Monitor', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Real-time watchState stream & on-demand preloading', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlacementStateMonitorScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined, color: TaskColors.amberText),
              title: const Text('AdMob Inspector', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Device ad verification & adapter health', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                AdmobKit.openAdInspector();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined, color: TaskColors.emeraldText),
              title: const Text('Privacy & Consent Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text('Google UMP GDPR privacy form', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(ctx).pop();
                AdmobKit.showPrivacyOptionsForm();
              },
            ),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: TaskColors.canvasGround,
          appBar: AppBar(
            backgroundColor: TaskColors.canvasGround,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: TaskColors.accentPrimary,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: TaskColors.accentPrimary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.token_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'TaskFlow',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: TaskColors.textInkPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              Center(
                child: SdkStatusBadge(
                  onTap: () => _showSdkInfoSheet(context),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Ad gallery',
                icon: const Icon(Icons.view_quilt_outlined),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const AdGalleryScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Diagnostics',
                icon: const Icon(Icons.terminal_rounded, color: TaskColors.accentPrimary),
                onPressed: () => AppDrawerConsole.show(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!store.isPremium)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: TaskColors.surfaceCard,
                    border: Border(
                      top: BorderSide(color: TaskColors.borderSubtle),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  child: const AdBannerView(
                    placement: SampleAds.splashBanner,
                  ),
                ),

              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: TaskColors.borderSubtle),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  backgroundColor: TaskColors.surfaceCard,
                  elevation: 0,
                  indicatorColor: TaskColors.accentSubtle,
                  height: 64,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) {
                    if (_currentIndex == index) return;
                    setState(() => _currentIndex = index);

                    if (TaskStore.instance.checkInterval('tab_navigation', interval: 3)) {
                      TaskStore.instance.appendLog(
                        '🧭 [Navigation] Tab navigation threshold reached. Triggering Interstitial...',
                      );
                      AdmobKit.show(
                        SampleAds.mainInterstitial,
                        onDismissed: () {
                          TaskStore.instance.appendLog(
                            '✅ [Navigation] Interstitial dismissed. Tab flow uninterrupted.',
                          );
                        },
                      );
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline_rounded, color: TaskColors.textSlateMedium),
                      selectedIcon: Icon(Icons.check_circle_rounded, color: TaskColors.accentPrimary),
                      label: 'Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined, color: TaskColors.textSlateMedium),
                      selectedIcon: Icon(Icons.folder_rounded, color: TaskColors.accentPrimary),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.timer_outlined, color: TaskColors.textSlateMedium),
                      selectedIcon: Icon(Icons.timer_rounded, color: TaskColors.accentPrimary),
                      label: 'Focus',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_rounded, color: TaskColors.textSlateMedium),
                      selectedIcon: Icon(Icons.insights_rounded, color: TaskColors.accentPrimary),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined, color: TaskColors.textSlateMedium),
                      selectedIcon: Icon(Icons.settings_rounded, color: TaskColors.accentPrimary),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
