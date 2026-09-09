import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/screens/sub_screens/create_task_screen.dart';
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
    TaskStore.instance.togglePremium(false);
  });

  testWidgets('CreateTaskScreen renders all verbatim slot strings in default form', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTaskScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. appbar.title
    expect(find.text('Create New Task'), findsOneWidget);

    // 2. field.title.label
    expect(find.text('TASK TITLE'), findsOneWidget);

    // 3. field.title.hint
    expect(find.text('e.g. Implement Paywall Close Guard'), findsOneWidget);

    // 4. field.desc.label
    expect(find.text('DESCRIPTION & NOTES'), findsOneWidget);

    // 5. field.desc.hint
    expect(
      find.text('Add technical specifications, acceptance criteria, or reminders...'),
      findsOneWidget,
    );

    // 6. section.category
    expect(find.text('CATEGORY'), findsOneWidget);

    // 7. section.priority
    expect(find.text('PRIORITY LEVEL'), findsOneWidget);

    // 8. action.save
    expect(find.text('Save Task'), findsOneWidget);

    // Verify exactly 8 text widgets rendered in default form (excluding SnackBar)
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    expect(textWidgets.length, 8);
  });

  testWidgets('Validation error displays verbatim error slot on empty save', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CreateTaskScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Save Task without entering a title
    await tester.tap(find.text('Save Task'));
    await tester.pump();

    // 9. error.empty_title rendered in SnackBar
    expect(find.text('Please enter a task title'), findsOneWidget);
  });

  testWidgets('Valid task creation stores task item in TaskStore and navigates back', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateTaskScreen), findsOneWidget);

    // Enter title
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Implement Paywall Close Guard'),
      'Architect Paywall Route Observer',
    );
    // Enter description
    await tester.enterText(
      find.widgetWithText(TextField, 'Add technical specifications, acceptance criteria, or reminders...'),
      'Ensure zero interruptions during modal forms.',
    );

    // Tap Save Task
    await tester.tap(find.text('Save Task'));
    await tester.pumpAndSettle();

    // Navigated back
    expect(find.byType(CreateTaskScreen), findsNothing);

    // Verify task is in TaskStore
    final store = TaskStore.instance;
    final created = store.tasks.firstWhere((t) => t.title == 'Architect Paywall Route Observer');
    expect(created.description, 'Ensure zero interruptions during modal forms.');
  });

  testWidgets('Reduced motion renders cleanly and functions properly', (tester) async {
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
          home: CreateTaskScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create New Task'), findsOneWidget);
    expect(find.text('Save Task'), findsOneWidget);
  });

  testWidgets('Route guarding suppresses App Open ads on mount and restores on unmount', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(name: CreateTaskScreen.routeName),
                builder: (_) => const CreateTaskScreen(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify suppressed log added
    expect(
      TaskStore.instance.liveLogs.value.any((l) => l.contains('CreateTaskScreen active: App Open ads suppressed')),
      isTrue,
    );

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Verify restored log added
    expect(
      TaskStore.instance.liveLogs.value.any((l) => l.contains('CreateTaskScreen dismissed: App Open ads restored')),
      isTrue,
    );
  });
}
