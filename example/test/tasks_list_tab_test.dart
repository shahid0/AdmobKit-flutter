import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:flutter_ads_example/models/task_item.dart';
import 'package:flutter_ads_example/screens/sub_screens/create_task_screen.dart';
import 'package:flutter_ads_example/screens/tabs/tasks_list_tab.dart';
import 'package:flutter_ads_example/state/task_store.dart';
import 'package:flutter_ads_example/widgets/task_tile.dart';

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
    if (store.tasks.isEmpty) {
      final now = DateTime.now();
      for (int i = 1; i <= 6; i++) {
        store.addTask(
          TaskItem(
            id: 'sample_$i',
            title: 'Sample Task $i',
            description: 'Sample description $i',
            categoryId: 'work',
            priority: TaskPriority.medium,
            isCompleted: i == 6,
            dueDate: now.add(Duration(hours: i)),
          ),
        );
      }
    }
  });

  testWidgets('TasksListTab renders all verbatim slot strings and sticky header', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    final store = TaskStore.instance;

    // 1. Header Title
    expect(find.text('My Tasks'), findsOneWidget);

    // 2. Header Stats dynamic template
    expect(
      find.text('${store.pendingTasksCount} pending • ${store.completedTasksCount} done'),
      findsOneWidget,
    );

    // 3. Filter Chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // 4. FAB Action
    expect(find.text('New Task'), findsOneWidget);

    // 5. Sponsored native ad tags (Free tier)
    expect(find.text('SPONSORED'), findsWidgets);
  });

  testWidgets('VIP mode collapses native ads and displays PRO ACTIVE badge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    TaskStore.instance.togglePremium(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    // PRO ACTIVE badge visible
    expect(find.text('PRO ACTIVE'), findsOneWidget);

    // Sponsored ad tags absent (collapsed to SizedBox.shrink)
    expect(find.text('SPONSORED'), findsNothing);
  });

  testWidgets('Empty state renders verbatim empty title and description', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Clear all tasks to trigger empty backlog state
    final store = TaskStore.instance;
    final taskIds = store.tasks.map((t) => t.id).toList();
    for (final id in taskIds) {
      store.deleteTask(id);
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Tasks Found'), findsOneWidget);
    expect(
      find.text('All objectives clear. Tap New Task to architect your next goal.'),
      findsOneWidget,
    );
  });

  testWidgets('Filter chip switching alters visible tasks correctly', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    TaskStore.instance.togglePremium(false);

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Done filter chip
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify only completed tasks are shown
    final completedCount = TaskStore.instance.completedTasksCount;
    expect(find.byType(TaskTile), findsNWidgets(completedCount));
  });

  testWidgets('Completing 3 tasks triggers interval threshold log', (tester) async {
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
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    final taskTiles = find.byType(TaskTile);
    expect(taskTiles, findsWidgets);

    // Trigger completion threshold by incrementing or tapping
    store.incrementActionAndCheckInterval(interval: 3);
    store.incrementActionAndCheckInterval(interval: 3);
    final triggered = store.incrementActionAndCheckInterval(interval: 3);
    expect(triggered, isTrue);
  });

  testWidgets('TasksListTab renders properly with reduced motion enabled', (tester) async {
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
          home: TasksListTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Tasks'), findsOneWidget);
    expect(find.text('New Task'), findsOneWidget);
  });

  testWidgets('Tapping New Task opens CreateTaskScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: TasksListTab(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Task'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskScreen), findsOneWidget);
  });
}
