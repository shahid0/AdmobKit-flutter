import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ads/flutter_ads.dart';
import 'package:flutter_ads/src/infrastructure/pool/ad_cache_entry.dart';

void main() {
  group('AdCacheEntry Freshness & TTL Tests', () {
    const placement = InterstitialPlacement(
      androidId: 'unit_android',
      iosId: 'unit_ios',
    );

    test('Identifies fresh ad within TTL', () {
      final entry = AdCacheEntry(
        placement: placement,
        adInstance: Object(),
        loadedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ttl: const Duration(minutes: 50),
      );

      expect(entry.isStale, false);
      expect(entry.age.inMinutes, greaterThanOrEqualTo(9));
    });

    test('Identifies stale ad past TTL', () {
      final entry = AdCacheEntry(
        placement: placement,
        adInstance: Object(),
        loadedAt: DateTime.now().subtract(const Duration(minutes: 55)),
        ttl: const Duration(minutes: 50),
      );

      expect(entry.isStale, true);
    });
  });
}
