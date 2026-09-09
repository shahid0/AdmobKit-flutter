import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/screens/onboarding_screen.dart';
import 'package:flutter_ads_example/screens/paywall_screen.dart';

class TestNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? replacedRoute;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacedRoute = newRoute;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
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

  testWidgets('OnboardingScreen verifies all 21 verbatim slots and navigation across 3 steps',
      (WidgetTester tester) async {
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
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Top Bar
    expect(find.text('Skip'), findsOneWidget);

    // --- STEP 1: ARCHITECTURE ---
    expect(find.text('STAGE 01 • ARCHITECTURE'), findsOneWidget);
    expect(find.text('Engineered for Focus'), findsOneWidget);
    expect(
      find.text(
          'A deliberate system designed to eliminate digital fatigue and align daily execution with macro objectives.'),
      findsOneWidget,
    );
    expect(find.text('Q3 System Architecture Review'), findsOneWidget);
    expect(find.text('High Priority'), findsOneWidget);
    expect(find.text('AdMob Mediation Layer Audit'), findsOneWidget);
    expect(find.text('0ms Mutex'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Zero ads on Step 1
    expect(find.byType(AdNativeView), findsNothing);

    // Tap Continue to navigate to Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // --- STEP 2: WORKSPACES ---
    expect(find.text('STAGE 02 • WORKSPACES'), findsOneWidget);
    expect(find.text('Unified Project Workspaces'), findsOneWidget);
    expect(
      find.text(
          'Categorize initiatives, isolate deep work sessions, and track execution velocity across multiple domains.'),
      findsOneWidget,
    );
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
    expect(find.byType(AdNativeView), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Continue to navigate to Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // --- STEP 3: MOMENTUM ---
    expect(find.text('STAGE 03 • MOMENTUM'), findsOneWidget);
    expect(find.text('Unbroken Daily Momentum'), findsOneWidget);
    expect(
      find.text(
          'Transform sporadic bursts into resilient systems with integrated Pomodoro blocks and velocity analytics.'),
      findsOneWidget,
    );
    expect(find.text('94.2%'), findsOneWidget);
    expect(find.text('Consistency Rate'), findsOneWidget);
    expect(find.text('18 Days'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    // Zero ads on Step 3
    expect(find.byType(AdNativeView), findsNothing);

    // Tap Get Started to trigger navigation
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    expect(observer.replacedRoute, isNotNull);
    final route = observer.replacedRoute as MaterialPageRoute;
    final targetWidget = route.builder(tester.element(find.byType(OnboardingScreen)));
    expect(targetWidget, isA<PaywallScreen>());
    final paywall = targetWidget as PaywallScreen;
    expect(paywall.isFromOnboarding, isTrue);
  });

  testWidgets('OnboardingScreen Skip button routes directly to PaywallScreen(isFromOnboarding: true)',
      (WidgetTester tester) async {
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
        home: const OnboardingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(observer.replacedRoute, isNotNull);
    final route = observer.replacedRoute as MaterialPageRoute;
    final targetWidget = route.builder(tester.element(find.byType(OnboardingScreen)));
    expect(targetWidget, isA<PaywallScreen>());
    final paywall = targetWidget as PaywallScreen;
    expect(paywall.isFromOnboarding, isTrue);
  });
}
