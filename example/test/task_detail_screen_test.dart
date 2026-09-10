import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:flutter_ads_example/models/task_item.dart';
import 'package:flutter_ads_example/screens/sub_screens/task_detail_screen.dart';
import 'package:flutter_ads_example/state/task_store.dart';

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
    store.addTask(
      TaskItem(
        id: 'detail_test_task',
        title: 'Review Q3 monetization metrics',
        description: 'Analyze AdMob eCPM, interstitial fill rates, and paywall conversions.',
        categoryId: 'work',
        priority: TaskPriority.high,
        isCompleted: false,
        dueDate: DateTime.now().add(const Duration(hours: 4)),
      ),
    );
  });

  testWidgets('TaskDetailScreen renders all verbatim slot strings and exactly 8 text nodes in free state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(taskId: 'detail_test_task'),
      ),
    );
    await tester.pumpAndSettle();

    // 1. appbar.title
    expect(find.text('Task Details'), findsOneWidget);

    // 2. action.delete (tooltip)
    expect(find.byTooltip('Delete Task'), findsOneWidget);

    // 3. badge.priority_suffix
    expect(find.text('High Priority'), findsOneWidget);

    // 4. action.complete (pending state)
    expect(find.text('Mark Completed'), findsOneWidget);

    // 5. section.subtasks
    expect(find.text('EXECUTION CHECKLIST'), findsOneWidget);

    // 6. ad.sponsored (free tier)
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
    expect(find.byType(AdNativeView), findsOneWidget);

    // 7. Verify exactly 8 text widgets rendered
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(8));
  });

  testWidgets('TaskDetailScreen fallback description renders when task description is empty', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.addTask(
      TaskItem(
        id: 'empty_desc_task',
        title: 'Empty description task',
        description: '',
        categoryId: 'personal',
        priority: TaskPriority.low,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(taskId: 'empty_desc_task'),
      ),
    );
    await tester.pumpAndSettle();

    // 4. desc.empty verbatim
    expect(find.text('No additional description provided.'), findsOneWidget);
  });

  testWidgets('TaskDetailScreen toggles completion state cleanly', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(taskId: 'detail_test_task'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark Completed'), findsOneWidget);

    // Tap complete button
    await tester.tap(find.text('Mark Completed'));
    await tester.pumpAndSettle();

    // Button label transitions to Mark Incomplete
    expect(find.text('Mark Incomplete'), findsOneWidget);
    expect(find.text('Mark Completed'), findsNothing);

    // Tap again to revert
    await tester.tap(find.text('Mark Incomplete'));
    await tester.pumpAndSettle();

    expect(find.text('Mark Completed'), findsOneWidget);
  });

  testWidgets('VIP mode collapses native ad container with zero layout shift', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    TaskStore.instance.togglePremium(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(taskId: 'detail_test_task'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SPONSORED RECOMMENDATION'), findsNothing);
    expect(find.byType(AdNativeView), findsNothing);

    // Exactly 7 text widgets (all slots except ad.sponsored)
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(7));
  });

  testWidgets('TaskDetailScreen renders properly with reduced motion enabled', (tester) async {
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
          home: TaskDetailScreen(taskId: 'detail_test_task'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task Details'), findsOneWidget);
    expect(find.text('Mark Completed'), findsOneWidget);
    expect(find.text('EXECUTION CHECKLIST'), findsOneWidget);
  });

  testWidgets('Deleting task pops route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaskDetailScreen(taskId: 'detail_test_task'),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open detail
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Task Details'), findsOneWidget);

    // Tap delete
    await tester.tap(find.byTooltip('Delete Task'));
    await tester.pumpAndSettle();

    // Popped back to home
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Task Details'), findsNothing);
  });
}
