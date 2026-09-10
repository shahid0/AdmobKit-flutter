import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:flutter_ads_example/screens/paywall_screen.dart';
import 'package:flutter_ads_example/screens/main_tabs_screen.dart';
import 'package:flutter_ads_example/config/sample_ads.dart';
import 'package:flutter_ads_example/state/task_store.dart';

class TestNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? replacedRoute;
  Route<dynamic>? removedRoute;
  Route<dynamic>? poppedRoute;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacedRoute = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removedRoute = route;
    super.didRemove(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoute = route;
    super.didPop(route, previousRoute);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await FlutterAds.initialize(
      config: const FlutterAdsConfig(
        placements: [],
        requestConsent: false,
        initializeNativeGma: false,
      ),
    );
  });

  setUp(() {
    TaskStore.instance.togglePremium(false);
  });

  testWidgets('PaywallScreen renders all 18 verbatim slots with exact text node count', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PaywallScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Top Bar
    expect(find.text('LIMITED ACCESS'), findsOneWidget);

    // 2. Hero
    expect(find.text('TaskFlow Pro VIP'), findsOneWidget);
    expect(find.text('Architectural focus without interruptions. Pure execution.'), findsOneWidget);

    // 3. Features
    expect(find.text('100% Ad-Free Ecosystem'), findsOneWidget);
    expect(find.text('Zero interstitials, banners, or video delays across all 15 workspaces.'), findsOneWidget);
    expect(find.text('Unlimited Deep Workspaces'), findsOneWidget);
    expect(find.text('Structure unbounded project hierarchies with instant filtering.'), findsOneWidget);
    expect(find.text('Automated Accomplishment Reports'), findsOneWidget);
    expect(find.text('Instant one-tap PDF exports without watching rewarded ads.'), findsOneWidget);
    expect(find.text('0ms Priority Engine'), findsOneWidget);
    expect(find.text('All executive features primed in memory with zero latency.'), findsOneWidget);

    // 4. Pricing Tiers
    expect(find.text('Annual Membership'), findsOneWidget);
    expect(find.text('3-Day Free Trial, then \$29.99/year'), findsOneWidget);
    expect(find.text('SAVE 50%'), findsOneWidget);
    expect(find.text('Monthly Membership'), findsOneWidget);
    expect(find.text('\$4.99/month'), findsOneWidget);

    // 5. Bottom Action Bar
    expect(find.text('Start 3-Day Free Trial'), findsOneWidget);
    expect(find.text('No commitment. Cancel anytime in App Store or Google Play.'), findsOneWidget);

    // Total Text widgets rendered MUST be exactly 18
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(18));
  });

  testWidgets('PaywallScreen toggles pricing tier selection state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PaywallScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially Annual is selected (checked icon)
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);

    // Scroll Monthly Membership into view and tap
    await tester.ensureVisible(find.text('Monthly Membership'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly Membership'));
    await tester.pumpAndSettle();

    // Checked icon still exists (now for Monthly)
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);

    // Scroll Annual Membership into view and tap
    await tester.ensureVisible(find.text('Annual Membership'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annual Membership'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });

  testWidgets('PaywallScreen purchase activates VIP mode and navigates cleanly without ads', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final observer = TestNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const PaywallScreen(isFromOnboarding: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(TaskStore.instance.isPremium, isFalse);

    // Tap CTA
    await tester.tap(find.text('Start 3-Day Free Trial'));
    await tester.pump();

    // VIP activated
    expect(TaskStore.instance.isPremium, isTrue);

    // Navigated to MainTabsScreen
    expect(observer.replacedRoute, isNotNull);
    final route = observer.replacedRoute as MaterialPageRoute;
    final targetWidget = route.builder(tester.element(find.byType(PaywallScreen)));
    expect(targetWidget, isA<MainTabsScreen>());
  });

  testWidgets('PaywallScreen renders correctly under reduced motion', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: PaywallScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // All slots remain fully legible
    expect(find.text('TaskFlow Pro VIP'), findsOneWidget);
    expect(find.text('Start 3-Day Free Trial'), findsOneWidget);
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(18));
  });

  testWidgets('PaywallScreen has AdPaywallGuard intercepting exits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PaywallScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdPaywallGuard), findsOneWidget);
    final guard = tester.widget<AdPaywallGuard>(find.byType(AdPaywallGuard));
    expect(guard.placement, equals(SampleAds.mainInterstitial));
  });
}
