import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ads/flutter_ads.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlutterAds initialization test', (WidgetTester tester) async {
    const placement = BannerPlacement(
      androidId: 'ca-app-pub-3940256099942544/6300978111',
      iosId: 'ca-app-pub-3940256099942544/2934735716',
    );

    await FlutterAds.initialize(
      config: const FlutterAdsConfig(
        placements: [placement],
        requestConsent: false,
      ),
    );

    expect(FlutterAds.isUserPremium, false);
  });
}
