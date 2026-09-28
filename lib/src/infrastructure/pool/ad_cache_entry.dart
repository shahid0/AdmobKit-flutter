import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/models/ad_placement.dart';

/// In-memory cache entry holding a primed ad instance with freshness tracking.
class AdCacheEntry {
  final AdPlacement placement;
  final dynamic adInstance;
  final DateTime loadedAt;
  final Duration ttl;

  AdCacheEntry({
    required this.placement,
    required this.adInstance,
    DateTime? loadedAt,
    this.ttl = const Duration(minutes: 50),
  }) : loadedAt = loadedAt ?? DateTime.now();

  /// Returns true if this ad has exceeded its time-to-live (50 mins by default).
  bool get isStale => DateTime.now().difference(loadedAt) > ttl;

  /// Time elapsed since this ad was loaded.
  Duration get age => DateTime.now().difference(loadedAt);

  /// Properly disposes the underlying platform ad instance.
  void dispose() {
    disposeAdInstance(adInstance);
  }

  /// Disposes inline and fullscreen platform ads, including discarded loads.
  static Future<void> disposeAdInstance(dynamic adInstance) async {
    try {
      if (adInstance is Ad) {
        await adInstance.dispose();
      }
    } catch (_) {}
  }
}
