import 'package:flutter_test/flutter_test.dart';
import 'package:admob_kit_flutter/flutter_ads.dart';

void main() {
  group('AdTimeoutConfig & Network Resolution Tests', () {
    test('Standard config resolves appropriate bounds for WiFi vs Cellular', () {
      const config = AdTimeoutConfig.standard;

      // Fullscreen
      final fsWifi = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi);
      final fsCellular = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular);
      expect(fsWifi, const Duration(seconds: 15));
      expect(fsCellular, const Duration(seconds: 25));

      // Inline
      final inlineWifi = config.resolve(format: AdFormat.banner, network: AdNetworkType.wifi);
      final inlineCellular = config.resolve(format: AdFormat.banner, network: AdNetworkType.cellular);
      expect(inlineWifi, const Duration(seconds: 10));
      expect(inlineCellular, const Duration(seconds: 15));

      // Splash
      final splashWifi = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi, isSplash: true);
      final splashCellular = config.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular, isSplash: true);
      expect(splashWifi, const Duration(seconds: 15));
      expect(splashCellular, const Duration(seconds: 25));
    });

    test('Aggressive and Relaxed profiles resolve correctly', () {
      const aggressive = AdTimeoutConfig.aggressive;
      expect(
        aggressive.resolve(format: AdFormat.interstitial, network: AdNetworkType.wifi),
        const Duration(seconds: 10),
      );

      const relaxed = AdTimeoutConfig.relaxed;
      expect(
        relaxed.resolve(format: AdFormat.interstitial, network: AdNetworkType.cellular),
        const Duration(seconds: 35),
      );
    });
  });
}
