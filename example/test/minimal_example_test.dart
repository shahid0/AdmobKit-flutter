import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads_example/minimal.dart';

void main() {
  testWidgets('minimal public example continues without an ad for premium users', (tester) async {
    await AdmobKitTestHarness.initialize(
      initializeNativeGma: false,
      config: AdmobKitConfig(requestConsent: false, isPremium: () => true),
    );
    addTearDown(AdmobKit.dispose);
    AdmobKit.registerPlacements([AppAds.transition, AppAds.native, AppAds.banner]);
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(AdBannerView), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Action completed'), findsOneWidget);
    expect(AdmobKit.isShowingAd, isFalse);
  });
}
