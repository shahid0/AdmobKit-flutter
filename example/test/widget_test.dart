import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/main.dart';

void main() {
  testWidgets('TaskFlowApp renders UI splash and brand identity', (WidgetTester tester) async {
    await FlutterAds.initialize(
      config: const FlutterAdsConfig(
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
