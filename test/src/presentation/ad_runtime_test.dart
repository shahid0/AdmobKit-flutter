import 'package:admob_kit_flutter/admob_kit_flutter.dart';
import 'package:admob_kit_flutter/src/domain/contracts/ad_network_info.dart';
import 'package:admob_kit_flutter/src/infrastructure/drivers/google_mobile_ads_driver.dart';
import 'package:admob_kit_flutter/src/presentation/ad_runtime.dart';
import 'package:admob_kit_flutter/src/presentation/admob_kit_test_harness.dart';
import 'package:admob_kit_flutter/src/presentation/widgets/ad_banner_view.dart' as banner;
import 'package:admob_kit_flutter/src/presentation/widgets/ad_native_view.dart' as native;
import 'package:admob_kit_flutter/src/presentation/widgets/ad_paywall_guard.dart' as paywall;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Network implements AdNetworkInfo {
  @override
  Future<AdNetworkType> getNetworkType() async => AdNetworkType.wifi;

  @override
  Stream<AdNetworkType> get onNetworkTypeChanged => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(AdmobKit.dispose);
  tearDown(AdmobKit.dispose);

  const config = AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none);

  test('initialization arguments compose the same session used by the facade and harness', () async {
    final driver = GoogleMobileAdsDriver();
    final network = _Network();
    await AdmobKitTestHarness.initialize(
      config: config,
      driver: driver,
      networkInfo: network,
      initializeNativeGma: false,
    );

    final session = activeAdSession!;
    expect(session.driver, same(driver));
    expect(session.networkInfo, same(network));
    expect(AdmobKitTestHarness.pool, same(session.pool));
    expect(AdmobKitTestHarness.presentationMutex, same(session.mutex));
    expect(AdmobKit.initializationStateListenable, same(adInitializationStateListenable));
    expect(AdmobKit.canRequestAds, isTrue);

    AdmobKit.dispose();
    expect(session.isDisposed, isTrue);
    expect(activeAdSession, isNull);
    expect(AdmobKit.initializationState, AdInitializationState.disposed);
  });

  test('concurrent calls preserve the first initialization and its dependencies', () async {
    final firstDriver = GoogleMobileAdsDriver();
    final firstNetwork = _Network();
    final first = AdmobKitTestHarness.initialize(
      config: config,
      driver: firstDriver,
      networkInfo: firstNetwork,
      initializeNativeGma: false,
    );
    final second = AdmobKitTestHarness.initialize(
      config: config,
      driver: GoogleMobileAdsDriver(),
      networkInfo: _Network(),
      initializeNativeGma: false,
    );
    expect(second, same(first));
    await first;
    expect(activeAdSession!.driver, same(firstDriver));
    expect(activeAdSession!.networkInfo, same(firstNetwork));
  });

  test('omitted arguments in a new session cannot reuse earlier test dependencies', () async {
    final driver = GoogleMobileAdsDriver();
    final network = _Network();
    await AdmobKitTestHarness.initialize(
      config: config,
      driver: driver,
      networkInfo: network,
      initializeNativeGma: false,
    );
    final oldSession = activeAdSession!;
    final stateListenable = AdmobKit.initializationStateListenable;
    AdmobKit.dispose();

    await AdmobKitTestHarness.initialize(config: config, initializeNativeGma: false);
    expect(activeAdSession, isNot(same(oldSession)));
    expect(activeAdSession!.driver, isNot(same(driver)));
    expect(activeAdSession!.networkInfo, isNot(same(network)));
    expect(AdmobKit.initializationStateListenable, same(stateListenable));
    expect(AdmobKit.canRequestAds, isTrue);
  });

  testWidgets('each widget library can be imported independently', (tester) async {
    await AdmobKitTestHarness.initialize(
      config: AdmobKitConfig(requestConsent: false, logLevel: AdLogLevel.none, isPremium: () => true),
      initializeNativeGma: false,
    );
    const bannerPlacement = BannerPlacement(androidId: 'test', iosId: 'test');
    const nativePlacement = NativePlacement(androidId: 'test', iosId: 'test');
    const exitPlacement = InterstitialPlacement(androidId: 'test', iosId: 'test');
    var exits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const banner.AdBannerView(placement: bannerPlacement),
              const native.AdNativeView(placement: nativePlacement),
              paywall.AdPaywallGuard(
                placement: exitPlacement,
                onDismiss: () => exits++,
                builder: (context, dismiss) => TextButton(onPressed: dismiss, child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AdBannerView), findsOneWidget);
    expect(find.byType(AdNativeView), findsOneWidget);
    expect(find.byType(AdPaywallGuard), findsOneWidget);
    await tester.tap(find.text('Close'));
    expect(exits, 1);
    expect(AdmobKit.isShowingAd, isFalse);
  });
}
