import '../models/ad_placement.dart';
import '../models/ad_revenue_value.dart';

/// Dependency Injection contract for routing ad events to product/marketing analytics.
///
/// Implement this interface to pipe events to Firebase, AppsFlyer, Mixpanel, Adjust, etc.
abstract interface class AdAnalyticsTracker {
  /// Handles the event emitted when an ad load request is dispatched to the network.
  void onAdRequested(AdPlacement placement);

  /// Handles the event emitted when an ad successfully finishes loading and is ready in memory.
  void onAdLoaded(AdPlacement placement, Duration loadTime);

  /// Handles the event emitted when an ad request fails.
  void onAdFailedToLoad(
    AdPlacement placement,
    String error,
    int? errorCode,
  );

  /// Handles the event emitted when a full-screen or inline ad is first displayed to the user.
  void onAdDisplayed(AdPlacement placement);

  /// Handles the event emitted when a full-screen ad is closed or dismissed by the user.
  void onAdDismissed(AdPlacement placement);

  /// Handles the event emitted when the user taps or clicks on an ad.
  void onAdClicked(AdPlacement placement);

  /// Handles the event emitted when impression-level ad revenue is reported by AdMob.
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue);
}
