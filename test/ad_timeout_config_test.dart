import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/admob_kit_flutter.dart';

void main() {
  group('AdTimeoutConfig & Network Resolution Tests', () {
    test('Standard config resolves appropriate bounds for WiFi vs Cellular', () {
      const config = AdTimeoutConfig.standard;

      // Fullscreen
      final fsWifi = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi);
      final fsCellular = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular);
      expect(fsWifi, const Duration(seconds: 30));
      expect(fsCellular, const Duration(seconds: 50));

      // Inline
      final inlineWifi = config.resolve(format: AdFormat.banner, network: AdNetworkType.wifi);
      final inlineCellular = config.resolve(format: AdFormat.banner, network: AdNetworkType.cellular);
      expect(inlineWifi, const Duration(seconds: 20));
      expect(inlineCellular, const Duration(seconds: 35));

      // Splash
      final splashWifi = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi, isSplash: true);
      final splashCellular = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular, isSplash: true);
      expect(splashWifi, const Duration(seconds: 25));
      expect(splashCellular, const Duration(seconds: 45));
    });

    test('Aggressive, Relaxed, and EmergingMarkets profiles resolve correctly', () {
      const aggressive = AdTimeoutConfig.aggressive;
      expect(
        aggressive.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi),
        const Duration(seconds: 15),
      );
      expect(
        aggressive.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular),
        const Duration(seconds: 25),
      );

      const relaxed = AdTimeoutConfig.relaxed;
      expect(
        relaxed.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular),
        const Duration(seconds: 60),
      );

      const emerging = AdTimeoutConfig.emergingMarkets;
      expect(
        emerging.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular),
        const Duration(seconds: 75),
      );
      expect(
        emerging.resolve(format: AdFormat.banner, network: AdNetworkType.cellular),
        const Duration(seconds: 50),
      );
      expect(
        emerging.resolve(format: AdFormat.appOpen, network: AdNetworkType.cellular, isSplash: true),
        const Duration(seconds: 65),
      );
    });
  });
}
