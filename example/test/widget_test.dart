import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads_example/main.dart';

void main() {
  testWidgets('FlutterAdsExampleApp renders UI controls properly', (WidgetTester tester) async {
    await FlutterAds.initialize(
      config: const FlutterAdsConfig(
        placements: [],
        requestConsent: false,
        initializeNativeGma: false,
      ),
    );

    await tester.pumpWidget(const FlutterAdsExampleApp());
    await tester.pump();

    // Verify main components render
    expect(find.text('FlutterAds Showcase'), findsOneWidget);
    expect(find.text('Show Interstitial'), findsOneWidget);
    expect(find.text('Show Rewarded (+50)'), findsOneWidget);
    expect(find.text('Live Analytics & Diagnostics Stream'), findsOneWidget);
  });
}
