import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter_ads_example/main.dart';

void main() {
  testWidgets('TaskFlowApp renders UI splash and brand identity', (WidgetTester tester) async {
    await AdmobKit.initialize(
      config: const AdmobKitConfig(
        placements: [],
        requestConsent: false,
        initializeNativeGma: false,
      ),
    );

    await tester.pumpWidget(const TaskFlowApp());
    await tester.pump();

    // Verify main splash components render
    expect(find.text('TaskFlow Pro'), findsOneWidget);
    expect(find.text('Architectural Clarity for High-Agency Builders'), findsOneWidget);
  });
}
