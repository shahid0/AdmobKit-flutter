import 'package:admob_kit_flutter/admob_kit_flutter.dart';
// ignore: implementation_imports
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart' show AdmobKitTestHarness;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads_example/screens/sub_screens/placement_state_monitor_screen.dart';

void main() {
  testWidgets('diagnostic banner state has a real layout and no obsolete preload controls', (tester) async {
    await AdmobKitTestHarness.initialize(
      initializeNativeGma: false,
      config: AdmobKitConfig(requestConsent: false, isPremium: () => true),
    );
    addTearDown(AdmobKit.dispose);
    await tester.pumpWidget(const MaterialApp(home: PlacementStateMonitorScreen()));
    expect(tester.takeException(), isNull);
    expect(find.byType(AdBannerView), findsOneWidget);
    expect(find.text('Preload'), findsNothing);
    expect(find.text('0ms Show'), findsNothing);
  });
}
