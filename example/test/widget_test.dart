import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:flutter_ads_example/main.dart';

void main() {
  testWidgets('TaskFlowApp renders UI splash and brand identity', (WidgetTester tester) async {
    await AdmobKitTestHarness.initialize(initializeNativeGma: false, config: const AdmobKitConfig(
        placements: [],
        requestConsent: false,),
    );

    await tester.pumpWidget(const TaskFlowApp());
    await tester.pump();

    // Verify main splash components render
    expect(find.text('TaskFlow Pro'), findsOneWidget);
    expect(find.text('Architectural Clarity for High-Agency Builders'), findsOneWidget);
  });
}
