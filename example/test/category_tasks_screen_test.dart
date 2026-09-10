import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';
import 'package:flutter_ads_example/models/category_item.dart';
import 'package:flutter_ads_example/models/task_item.dart';
import 'package:flutter_ads_example/screens/sub_screens/category_tasks_screen.dart';
import 'package:flutter_ads_example/screens/sub_screens/task_detail_screen.dart';
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

  const testCategory = CategoryItem(
    id: 'work',
    name: 'Work & Projects',
    icon: Icons.work_rounded,
    color: Color(0xFF6366F1),
  );

  const otherCategory = CategoryItem(
    id: 'personal',
    name: 'Personal Life',
    icon: Icons.person_rounded,
    color: Color(0xFFEC4899),
  );

  setUp(() {
    final store = TaskStore.instance;
    store.togglePremium(false);
    final taskIds = store.tasks.map((t) => t.id).toList();
    for (final id in taskIds) {
      store.deleteTask(id);
    }
  });

  testWidgets('CategoryTasksScreen renders verbatim empty slots and bottom ad in Free tier', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    // 1. AppBar Category Icon & Workspace Title
    expect(find.text(testCategory.name), findsOneWidget);
    expect(find.byIcon(testCategory.icon), findsNWidgets(2)); // in AppBar and in empty state card

    // 2. empty.title slot verbatim
    expect(find.text('No tasks in this workspace'), findsOneWidget);

    // 3. empty.desc slot verbatim
    expect(
      find.text('All objectives clear. Tap the floating action button to create objectives under this category.'),
      findsOneWidget,
    );

    // 4. ad.sponsored slot verbatim (Free tier)
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
    expect(find.byType(AdNativeView), findsOneWidget);
  });

  testWidgets('VIP mode collapses native ad container with zero layout shift and renders exactly 3 text nodes in empty state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    TaskStore.instance.togglePremium(true);

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    // Ad is collapsed completely
    expect(find.text('SPONSORED RECOMMENDATION'), findsNothing);
    expect(find.byType(AdNativeView), findsNothing);

    // Empty state slots remain visible
    expect(find.text('No tasks in this workspace'), findsOneWidget);
    expect(
      find.text('All objectives clear. Tap the floating action button to create objectives under this category.'),
      findsOneWidget,
    );
    expect(find.text(testCategory.name), findsOneWidget);

    // Exactly 3 text nodes rendered: AppBar title, empty.title, empty.desc
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, equals(3));
  });

  testWidgets('CategoryTasksScreen filters tasks strictly to the given category', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    // Task in 'work' category
    store.addTask(
      TaskItem(
        id: 'work_task_1',
        title: 'Review Sprint Architecture',
        description: 'Ensure memory leak guards and composited animations adhere to budget.',
        categoryId: testCategory.id,
        priority: TaskPriority.high,
        dueDate: DateTime.now().add(const Duration(hours: 2)),
      ),
    );
    // Task in 'personal' category (should not appear)
    store.addTask(
      TaskItem(
        id: 'personal_task_1',
        title: 'Grocery shopping',
        description: 'Almond milk and cold brew.',
        categoryId: otherCategory.id,
        priority: TaskPriority.low,
        dueDate: DateTime.now().add(const Duration(hours: 5)),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    // Only work task should be visible
    expect(find.text('Review Sprint Architecture'), findsOneWidget);
    expect(find.text('Grocery shopping'), findsNothing);
    expect(find.byType(TaskTile), findsOneWidget);

    // Empty state should not be visible
    expect(find.text('No tasks in this workspace'), findsNothing);

    // Ad is still visible in Free tier
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
  });

  testWidgets('Toggling task completion updates state tactually', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.addTask(
      TaskItem(
        id: 'toggle_task',
        title: 'Test completion toggle',
        description: 'Verify checkbox state change.',
        categoryId: testCategory.id,
        priority: TaskPriority.medium,
        isCompleted: false,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.tasks.firstWhere((t) => t.id == 'toggle_task').isCompleted, isFalse);

    // Tap checkbox inside TaskTile
    await tester.tap(find.byType(AnimatedContainer));
    await tester.pumpAndSettle();

    expect(store.tasks.firstWhere((t) => t.id == 'toggle_task').isCompleted, isTrue);
  });

  testWidgets('Tapping task opens TaskDetailScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.addTask(
      TaskItem(
        id: 'nav_task',
        title: 'Navigation Test Task',
        description: 'Tap to navigate to details.',
        categoryId: testCategory.id,
        priority: TaskPriority.high,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Navigation Test Task'), findsOneWidget);

    // Tap task tile
    await tester.tap(find.text('Navigation Test Task'));
    await tester.pumpAndSettle();

    // Navigated to TaskDetailScreen
    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(find.text('Task Details'), findsOneWidget);

    // Pop back
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryTasksScreen), findsOneWidget);
  });

  testWidgets('CategoryTasksScreen renders cleanly with reduced motion enabled', (tester) async {
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
          home: CategoryTasksScreen(category: testCategory),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(testCategory.name), findsOneWidget);
    expect(find.text('No tasks in this workspace'), findsOneWidget);
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
  });

  testWidgets('Deleting a task removes it from the workspace and triggers empty state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.addTask(
      TaskItem(
        id: 'delete_task_1',
        title: 'Task to be dismissed',
        description: 'Swipe to dismiss',
        categoryId: testCategory.id,
        priority: TaskPriority.low,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoryTasksScreen(category: testCategory),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task to be dismissed'), findsOneWidget);
    expect(find.text('No tasks in this workspace'), findsNothing);

    // Dismiss task
    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    // Now empty state is shown
    expect(find.text('Task to be dismissed'), findsNothing);
    expect(find.text('No tasks in this workspace'), findsOneWidget);
    expect(
      find.text('All objectives clear. Tap the floating action button to create objectives under this category.'),
      findsOneWidget,
    );
  });
}
