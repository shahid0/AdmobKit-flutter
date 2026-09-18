import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdmobKit initialization test', (WidgetTester tester) async {
    const placement = BannerPlacement(
      androidId: 'ca-app-pub-3940256099942544/6300978111',
      iosId: 'ca-app-pub-3940256099942544/2934735716',
    );

    await AdmobKit.initialize(
      config: const AdmobKitConfig(
        placements: [placement],
        requestConsent: false,
      ),
    );

    expect(AdmobKit.isUserPremium, false);
  });
}
