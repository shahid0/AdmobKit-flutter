import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';

void main() {
  group('Widget Tests', () {
    testWidgets('AdBannerView collapses to SizedBox.shrink when user is premium', (tester) async {
      await FlutterAds.initialize(
        config: FlutterAdsConfig(
          placements: const [],
          requestConsent: false,
          initializeNativeGma: false,
          isPremium: () => true, // User is premium
        ),
      );

      const banner = BannerPlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdBannerView(
              placement: banner,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(AdBannerView), findsOneWidget);
      // SizedBox.shrink has zero size
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('AdNativeView collapses to SizedBox.shrink when user is premium', (tester) async {
      await FlutterAds.initialize(
        config: FlutterAdsConfig(
          placements: const [],
          requestConsent: false,
          initializeNativeGma: false,
          isPremium: () => true,
        ),
      );

      const native = NativePlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdNativeView(
              placement: native,
              height: 100,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 0.0);
      expect(sizedBox.height, 0.0);
    });

    testWidgets('AdNativeView reserves template default height when loading', (tester) async {
      await FlutterAds.initialize(
        config: const FlutterAdsConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const bigNative = NativePlacement.big(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdNativeView(
              placement: bigNative,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 300.0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AdPaywallGuard renders child content properly', (tester) async {
      await FlutterAds.initialize(
        config: const FlutterAdsConfig(
          placements: [],
          requestConsent: false,
          initializeNativeGma: false,
        ),
      );

      const inter = InterstitialPlacement(androidId: '1', iosId: '1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdPaywallGuard(
              placement: inter,
              onDismiss: () {},
              child: const Text('Premium Features'),
            ),
          ),
        ),
      );

      expect(find.text('Premium Features'), findsOneWidget);
      expect(find.byWidgetPredicate((widget) => widget is PopScope), findsOneWidget);
    });
  });
}
