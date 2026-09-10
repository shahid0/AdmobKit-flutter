import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:flutter_ads_example/screens/paywall_screen.dart';
import 'package:flutter_ads_example/screens/tabs/settings_tab.dart';
import 'package:flutter_ads_example/state/task_store.dart';
import 'package:flutter_ads_example/theme/task_theme.dart';
import 'package:flutter_ads_example/widgets/app_drawer_console.dart';

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
    final store = TaskStore.instance;
    store.togglePremium(false);
  });

  testWidgets('SettingsTab renders all verbatim slot strings in Free tier', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header slots
    expect(find.text('Settings & Ad Controls'), findsOneWidget);
    expect(
      find.text('Enterprise monetization diagnostics and subscription simulation.'),
      findsOneWidget,
    );

    // 2. VIP Card slots (Free tier)
    expect(find.text('Free Ad-Supported Tier'), findsOneWidget);
    expect(
      find.text('Toggle switch to test instant VIP ad suppression.'),
      findsOneWidget,
    );

    // Active VIP strings must NOT appear
    expect(find.text('TaskFlow PRO Active'), findsNothing);
    expect(find.text('All ads suppressed globally with zero latency.'), findsNothing);

    // 3. Section label
    expect(find.text('MONETIZATION & ADS VERIFICATION'), findsOneWidget);

    // 4. Action Tile 1: Paywall
    expect(find.text('View Paywall Screen'), findsOneWidget);
    expect(
      find.text('Test paywall close guard & back press ad interception'),
      findsOneWidget,
    );

    // 5. Action Tile 2: Interstitial
    expect(find.text('Test Interstitial Ad'), findsOneWidget);
    expect(
      find.text('Verify that dismissing does NOT trigger an App Open ad'),
      findsOneWidget,
    );

    // 6. Action Tile 3: Rewarded
    expect(find.text('Watch Ad: Unlock Executive Theme'), findsOneWidget);
    expect(
      find.text('Watch short video ad to unlock custom styling'),
      findsOneWidget,
    );
    expect(find.text('Theme Unlocked (Reward Granted)'), findsNothing);

    // 7. Action Tile 4: App Open
    expect(find.text('Show App Open Ad Directly'), findsOneWidget);
    expect(
      find.text('Present primed App Open ad on demand'),
      findsOneWidget,
    );

    // 8. Action Tile 5: AdMob Inspector
    expect(find.text('Open AdMob Inspector'), findsOneWidget);
    expect(
      find.text('Validate adapters, SDK initialization, and test ads'),
      findsOneWidget,
    );

    // 9. Action Tile 6: Privacy & GDPR Consent
    expect(find.text('Privacy & GDPR Consent Options'), findsOneWidget);
    expect(find.text('Present Google UMP consent form'), findsOneWidget);

    // 10. Action Tile 7: Ad Console & Event Feed
    expect(find.text('Live Ad Console & Event Feed'), findsOneWidget);
    expect(
      find.text('Inspect analytics impressions, revenue paid events & diagnostics'),
      findsOneWidget,
    );

    // Verify exactly 19 text nodes rendered in free tier state
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(19));
  });

  testWidgets('VIP switch toggles PRO mode with verbatim active strings dynamically', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially in Free tier
    expect(store.isPremium, isFalse);
    expect(find.text('Free Ad-Supported Tier'), findsOneWidget);

    // Toggle VIP Switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Verify TaskStore is updated
    expect(store.isPremium, isTrue);

    // Verify PRO Active slot strings are rendered
    expect(find.text('TaskFlow PRO Active'), findsOneWidget);
    expect(
      find.text('All ads suppressed globally with zero latency.'),
      findsOneWidget,
    );

    // Free tier strings absent
    expect(find.text('Free Ad-Supported Tier'), findsNothing);
    expect(
      find.text('Toggle switch to test instant VIP ad suppression.'),
      findsNothing,
    );

    // Text count remains invariant at 19
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(19));

    // Toggle back to Free
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(store.isPremium, isFalse);
    expect(find.text('Free Ad-Supported Tier'), findsOneWidget);
  });

  testWidgets('Unlocking executive theme renders verbatim unlocked slot in StatusBadge', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Unlock theme
    store.unlockProTheme();
    await tester.pumpAndSettle();

    // Unlocked slot rendered
    expect(find.text('Theme Unlocked (Reward Granted)'), findsOneWidget);
    expect(find.text('Watch short video ad to unlock custom styling'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Text count remains invariant at 19
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(19));
  });

  testWidgets('Tapping View Paywall Screen navigates to PaywallScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Paywall Screen'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('Tapping Test Interstitial Ad executes FlutterAds.show and logs verification', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test Interstitial Ad'));
    await tester.pumpAndSettle();

    expect(
      store.liveLogs.value.any((log) => log.contains('No App Open ad collision!')),
      isTrue,
    );
  });

  testWidgets('Tapping Show App Open Ad Directly logs on demand presentation', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show App Open Ad Directly'));
    await tester.pumpAndSettle();

    expect(
      store.liveLogs.value.any((log) => log.contains('App Open ad')),
      isTrue,
    );
  });

  testWidgets('Tapping Open AdMob Inspector executes without throwing', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open AdMob Inspector'));
    await tester.pumpAndSettle();

    expect(
      store.liveLogs.value.any((log) => log.contains('Inspector')),
      isTrue,
    );
  });

  testWidgets('Tapping Privacy & GDPR Consent Options logs UMP privacy form result', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy & GDPR Consent Options'));
    await tester.pumpAndSettle();

    expect(
      store.liveLogs.value.any((log) => log.contains('UMP')),
      isTrue,
    );
  });

  testWidgets('Tapping Live Ad Console & Event Feed presents AppDrawerConsole bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live Ad Console & Event Feed'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDrawerConsole), findsOneWidget);
  });

  testWidgets('Tactile active compression scales action tile to 0.97 on press down', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsTab(),
      ),
    );
    await tester.pumpAndSettle();

    final tileFinder = find.widgetWithText(TaskCard, 'Test Interstitial Ad');
    expect(tileFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(tileFinder));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));

    final scaleFinder = find.descendant(
      of: find.widgetWithText(TactileButton, 'Test Interstitial Ad'),
      matching: find.byType(ScaleTransition),
    );
    expect(scaleFinder, findsOneWidget);

    final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();

    // Settled geometry equals static (scale 1.0)
    final settledScaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(settledScaleWidget.scale.value, equals(1.0));
  });

  testWidgets('Reduced motion renders legible UI without animation errors', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SettingsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings & Ad Controls'), findsOneWidget);
    expect(find.text('MONETIZATION & ADS VERIFICATION'), findsOneWidget);
  });

  testWidgets('Accommodates large accessibility dynamic text scaling without clipping', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: SettingsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings & Ad Controls'), findsOneWidget);
  });
}
