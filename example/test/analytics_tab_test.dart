import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/models/task_item.dart';
import 'package:flutter_ads_example/screens/tabs/analytics_tab.dart';
import 'package:flutter_ads_example/state/task_store.dart';
import 'package:flutter_ads_example/theme/task_theme.dart';

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
    final taskIds = store.tasks.map((t) => t.id).toList();
    for (final id in taskIds) {
      store.deleteTask(id);
    }
  });

  testWidgets('AnalyticsTab renders all verbatim slot strings in Free tier', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    // Add 1 pending task and 1 completed task
    store.addTask(
      TaskItem(
        id: 'task_1',
        title: 'Draft Quarterly Architecture Spec',
        description: 'Detail all mechanical assertions',
        categoryId: 'work',
        priority: TaskPriority.high,
        isCompleted: false,
        dueDate: DateTime.now(),
      ),
    );
    store.addTask(
      TaskItem(
        id: 'task_2',
        title: 'Code Review Core Telemetry',
        description: 'Verify 0ms latency guarantees',
        categoryId: 'work',
        priority: TaskPriority.medium,
        isCompleted: true,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Header slots
    expect(find.text('Productivity Velocity'), findsOneWidget);
    expect(
      find.text('Quantitative completion momentum across active initiatives.'),
      findsOneWidget,
    );

    // 2. Velocity card slots
    expect(find.text('Completion Velocity'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 of 2 tasks completed'), findsOneWidget);

    // 3. Stat card slots
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('5 Days'), findsOneWidget);
    expect(find.text('Pending Tasks'), findsOneWidget);
    expect(find.text('Completed Tasks'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2)); // 1 pending, 1 completed

    // 4. Export section slots (Free tier)
    expect(find.text('REWARDED EXPORT'), findsOneWidget);
    expect(find.text('Executive Accomplishment Report'), findsOneWidget);
    expect(
      find.text(
        'Generate a structured PDF summarizing task completion velocity and workspace distribution.',
      ),
      findsOneWidget,
    );
    expect(find.text('Watch Ad to Export PDF'), findsOneWidget);
  });

  testWidgets('VIP tier hides REWARDED EXPORT badge and renders VIP button label', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.togglePremium(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // REWARDED EXPORT badge must be hidden for VIP
    expect(find.text('REWARDED EXPORT'), findsNothing);

    // Free button absent, VIP button present
    expect(find.text('Watch Ad to Export PDF'), findsNothing);
    expect(find.text('Export PDF (VIP Instant)'), findsOneWidget);
  });

  testWidgets('VIP mode tap triggers instant Accomplishment Report dialog without ad', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.togglePremium(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap VIP Instant export button
    await tester.tap(find.text('Export PDF (VIP Instant)'));
    await tester.pumpAndSettle();

    // Dialog slots rendered
    expect(find.text('Report Compiled'), findsOneWidget);
    expect(
      find.text(
        'Your executive accomplishment PDF report has been compiled successfully.',
      ),
      findsOneWidget,
    );
    expect(find.text('Done'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Dialog closed
    expect(find.text('Report Compiled'), findsNothing);
  });

  testWidgets('Free mode tap triggers rewarded flow and logs intent', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.togglePremium(false);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Watch Ad to Export PDF button
    await tester.tap(find.text('Watch Ad to Export PDF'));
    await tester.pumpAndSettle();

    // Verify log entry was recorded
    expect(
      store.liveLogs.value.any(
        (log) => log.contains('[Rewarded] User opted in to watch Rewarded Ad for PDF Export'),
      ),
      isTrue,
    );
  });

  testWidgets('Velocity card calculates 0% when there are zero tasks', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    expect(store.totalTasksCount, equals(0));

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('0 of 0 tasks completed'), findsOneWidget);
  });

  testWidgets('Tactile active press compresses button scale to 0.97', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsTab(),
      ),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(TactileButton, 'Watch Ad to Export PDF');
    expect(buttonFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));

    final scaleFinder = find.descendant(
      of: buttonFinder,
      matching: find.byType(ScaleTransition),
    );
    expect(scaleFinder, findsOneWidget);

    final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Accommodates large accessibility dynamic text scaling without errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: AnalyticsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Productivity Velocity'), findsOneWidget);
    expect(find.text('Completion Velocity'), findsOneWidget);
  });

  testWidgets('Reduced motion renders legible UI without animation errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: AnalyticsTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Productivity Velocity'), findsOneWidget);
    expect(find.text('REWARDED EXPORT'), findsOneWidget);
  });
}
