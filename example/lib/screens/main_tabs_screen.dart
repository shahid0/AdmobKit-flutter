import 'package:flutter/material.dart';
import 'package:flutter_ads/flutter_ads.dart';
import '../config/sample_ads.dart';
import '../state/task_store.dart';
import '../widgets/app_drawer_console.dart';
import 'tabs/tasks_list_tab.dart';
import 'tabs/categories_tab.dart';
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
    AnalyticsTab(),
    SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Rule: Funnel-Tied Priming. Resume App Open ads are only active once the user enters the main tabs!
    FlutterAds.resumeAppOpen();
    TaskStore.instance.appendLog('🏠 User entered Main Tabs container. App Open resume ads enabled.');
  }

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
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF9333EA)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TaskFlow',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.terminal_rounded, color: Color(0xFF67E8F9)),
                tooltip: 'Live Ad Console',
                onPressed: () => AppDrawerConsole.show(context),
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
              // Bottom Sticky Banner Ad (Collapses cleanly with zero shift for VIP!)
              if (!store.isPremium)
                const AdBannerView(
                  placement: SampleAds.splashBanner,
                ),

              // Bottom Navigation Bar
              NavigationBar(
                selectedIndex: _currentIndex,
                backgroundColor: const Color(0xFF14141A),
                indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white60),
                    selectedIcon: Icon(Icons.check_circle_rounded, color: Color(0xFF818CF8)),
                    label: 'Tasks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined, color: Colors.white60),
                    selectedIcon: Icon(Icons.folder_rounded, color: Color(0xFF818CF8)),
                    label: 'Categories',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_rounded, color: Colors.white60),
                    selectedIcon: Icon(Icons.insights_rounded, color: Color(0xFF818CF8)),
                    label: 'Analytics',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined, color: Colors.white60),
                    selectedIcon: Icon(Icons.settings_rounded, color: Color(0xFF818CF8)),
                    label: 'Settings',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
