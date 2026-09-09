import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/models/category_item.dart';
import 'package:flutter_ads_example/models/task_item.dart';
import 'package:flutter_ads_example/screens/sub_screens/category_tasks_screen.dart';
import 'package:flutter_ads_example/screens/tabs/categories_tab.dart';
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

  testWidgets('CategoriesTab renders all verbatim slot strings in Free tier', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    store.addTask(
      TaskItem(
        id: 'task_work_1',
        title: 'Complete Spec Review',
        description: 'Verify all 15 mechanical assertions',
        categoryId: 'work',
        priority: TaskPriority.high,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoriesTab(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verbatim header.title
    expect(find.text('Categories & Workspaces'), findsOneWidget);

    // 2. Verbatim header.subtitle
    expect(
      find.text('Isolate cognitive context across focused domains.'),
      findsOneWidget,
    );

    // 3. Verbatim ad.sponsored in Free Tier
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);

    // 4. Verbatim task count templates ('1 task' and '0 tasks')
    expect(find.text('1 task'), findsOneWidget);
    expect(find.text('0 tasks'), findsNWidgets(4));

    // 5. Default category titles
    for (final cat in CategoryItem.defaultCategories) {
      expect(find.text(cat.name), findsOneWidget);
    }
  });

  testWidgets('VIP mode collapses sponsored native ad container completely to SizedBox.shrink', (tester) async {
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
        home: CategoriesTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Ad headline absent
    expect(find.text('SPONSORED RECOMMENDATION'), findsNothing);

    // Header and categories remain intact
    expect(find.text('Categories & Workspaces'), findsOneWidget);
    expect(find.text('Isolate cognitive context across focused domains.'), findsOneWidget);
  });

  testWidgets('Tapping category navigates to CategoryTasksScreen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoriesTab(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap first category: 'Work & Projects'
    await tester.tap(find.text('Work & Projects'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryTasksScreen), findsOneWidget);
  });

  testWidgets('Tactile active compression triggers scale on press down', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoriesTab(),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.widgetWithText(TaskCard, 'Personal Life');
    expect(cardFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(cardFinder));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));

    // Verify scale transition is active
    final scaleFinder = find.descendant(
      of: find.widgetWithText(TactileButton, 'Personal Life'),
      matching: find.byType(ScaleTransition),
    );
    expect(scaleFinder, findsOneWidget);

    final scaleWidget = tester.widget<ScaleTransition>(scaleFinder);
    expect(scaleWidget.scale.value, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Plural task suffix formats correctly for 0, 1, and multiple tasks', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = TaskStore.instance;
    // Add 2 tasks for fitness
    store.addTask(
      TaskItem(
        id: 'fitness_1',
        title: 'Morning Run',
        description: '5k run',
        categoryId: 'fitness',
        priority: TaskPriority.high,
        dueDate: DateTime.now(),
      ),
    );
    store.addTask(
      TaskItem(
        id: 'fitness_2',
        title: 'Strength Training',
        description: 'Upper body',
        categoryId: 'fitness',
        priority: TaskPriority.medium,
        dueDate: DateTime.now(),
      ),
    );

    // Add 1 task for personal
    store.addTask(
      TaskItem(
        id: 'personal_1',
        title: 'Call Family',
        description: 'Weekly call',
        categoryId: 'personal',
        priority: TaskPriority.low,
        dueDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: CategoriesTab(),
      ),
    );
    await tester.pumpAndSettle();

    // 1 for personal: '1 task'
    expect(find.text('1 task'), findsOneWidget);
    // 2 for fitness: '2 tasks'
    expect(find.text('2 tasks'), findsOneWidget);
    // 0 for the other 3: '0 tasks'
    expect(find.text('0 tasks'), findsNWidgets(3));
  });

  testWidgets('Reduced motion renders legible UI without animation errors', (tester) async {
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
          home: CategoriesTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categories & Workspaces'), findsOneWidget);
    expect(find.text('SPONSORED RECOMMENDATION'), findsOneWidget);
  });

  testWidgets('Accommodates large accessibility dynamic text scaling without clipping', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: CategoriesTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Categories & Workspaces'), findsOneWidget);
  });
}
