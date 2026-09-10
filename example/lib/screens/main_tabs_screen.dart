import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../theme/task_theme.dart';
import '../widgets/app_drawer_console.dart';
import 'tabs/tasks_list_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/focus_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/settings_tab.dart';

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
              TactileButton(
                onTap: () => AppDrawerConsole.show(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TaskColors.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TaskColors.borderSubtle),
                    boxShadow: TaskColors.cardShadow,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terminal_rounded, color: TaskColors.accentPrimary, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Live Diagnostic HUD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: TaskColors.textInkPrimary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Sticky Banner Ad (Framed architectural container; collapses with zero shift for VIP!)
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

              // Bottom 5-Hub Architectural Navigation Bar
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
                      FlutterAds.show(
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
