import '../models/ad_placement.dart';
import '../models/ad_revenue_value.dart';

/// Dependency Injection contract for routing ad events to product/marketing analytics.
///
/// Implement this interface to pipe events to Firebase, AppsFlyer, Mixpanel, Adjust, etc.
///
/// Load callbacks ([onAdRequested], [onAdLoaded], [onAdFailedToLoad]) represent
/// **logical load cycles** managed by the pool rather than individual underlying SDK retry attempts:
/// - [onAdRequested] is emitted once when a logical load request begins.
/// - Transient errors retried by the queue do not fire [onAdFailedToLoad]; instead, each attempt
///   is reported individually through [AdDiagnosticsTracker.onDiagnosticReport].
/// - When the logical load settles, exactly one outcome is emitted: either [onAdLoaded]
///   with total elapsed duration upon readiness, or [onAdFailedToLoad] upon terminal failure
///   (fatal error, exhausted retries, or timeout). Contradictory or double-counted outcomes
///   are never emitted.
abstract interface class AdAnalyticsTracker {
  /// Handles the event emitted when a logical ad load request is dispatched to the network.
  void onAdRequested(AdPlacement placement);

  /// Handles the event emitted when an ad successfully finishes loading and is ready in memory.
  ///
  /// [loadTime] reflects the total elapsed duration from initial request dispatch until readiness.
  void onAdLoaded(AdPlacement placement, Duration loadTime);

  /// Handles the event emitted when a logical ad request fails terminally.
  ///
  /// This callback is invoked only when all retry attempts have settled in failure or a fatal
  /// non-retryable SDK error or timeout occurred. Transient attempts that are retried do not
  /// invoke this method.
  void onAdFailedToLoad(
    AdPlacement placement,
    String error,
    int? errorCode,
  );

  /// Reports SDK fullscreen display. Inline impressions are not reported here.
  void onAdDisplayed(AdPlacement placement);

  /// Handles the event emitted when a full-screen ad is closed or dismissed by the user.
  void onAdDismissed(AdPlacement placement);

  /// Handles the event emitted when the user taps or clicks on an ad.
  void onAdClicked(AdPlacement placement);

  /// Handles the event emitted when impression-level ad revenue is reported by AdMob.
  void onPaidEvent(AdPlacement placement, AdRevenueValue revenue);
}
