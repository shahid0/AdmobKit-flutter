import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, BoxConstraints constraints) => MaterialApp(
  home: Center(
    child: OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
      child: ConstrainedBox(constraints: constraints, child: child),
    ),
  ),
);

void main() {
  for (final template in [NativeAdTemplate.feedMediaFirst, NativeAdTemplate.fullscreenMediaFirst]) {
    final view = AdNativeView(
      placement: NativePlacement(androidId: 'test', iosId: 'test', template: template),
      active: false,
      placeholder: const Text('Native placeholder'),
    );

    testWidgets('${template.name} recovers from zero width and zero height frames', (tester) async {
      for (final size in [Size.zero, const Size(0, 400), const Size(400, 0)]) {
        await tester.pumpWidget(_host(view, BoxConstraints.tight(size)));
        expect(tester.takeException(), isNull);
        final collapsed = tester.widget<SizedBox>(
          find.descendant(of: find.byType(AdNativeView), matching: find.byType(SizedBox)),
        );
        expect(collapsed.width, 0);
        expect(collapsed.height, 0);

        await tester.pumpWidget(_host(view, BoxConstraints.tight(const Size(400, 400))));
        expect(tester.takeException(), isNull);
        expect(find.text('Native placeholder'), findsOneWidget);
      }
    });

    for (final constraints in [
      const BoxConstraints(maxHeight: 400),
      BoxConstraints.tight(const Size(100, 400)),
      if (template.isFullscreen) const BoxConstraints.tightFor(width: 400),
      if (template.isFullscreen) BoxConstraints.tight(const Size(400, 100)),
    ]) {
      testWidgets('${template.name} rejects invalid positive layout $constraints', (tester) async {
        await tester.pumpWidget(_host(view, constraints));
        expect(tester.takeException(), isA<FlutterError>());
      });
    }
  }

  for (final width in <double?>[null, 320]) {
    testWidgets('banner recovers from zero parent width with explicit width $width', (tester) async {
      final view = AdBannerView(
        placement: const BannerPlacement(androidId: 'test', iosId: 'test', sizing: BannerSizing.standard()),
        width: width,
        active: false,
      );
      await tester.pumpWidget(_host(view, BoxConstraints.tight(const Size(0, 50))));
      expect(tester.takeException(), isNull);
      final collapsed = tester.widget<SizedBox>(
        find.descendant(of: find.byType(AdBannerView), matching: find.byType(SizedBox)),
      );
      expect(collapsed.width, 0);
      expect(collapsed.height, 0);

      await tester.pumpWidget(_host(view, BoxConstraints.tight(const Size(400, 50))));
      expect(tester.takeException(), isNull);
      final expanded = tester.widget<SizedBox>(
        find.descendant(of: find.byType(AdBannerView), matching: find.byType(SizedBox)),
      );
      expect(expanded.width, 400);
      expect(expanded.height, 50);
    });
  }
}
