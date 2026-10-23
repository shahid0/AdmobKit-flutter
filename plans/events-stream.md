# Plan: `AdmobKit.events` stream

Release: 0.1.3 adds the stream and deprecates `AdmobKitConfig.analytics` / `diagnostics`. 0.2.0 removes them.

## Why

`AdmobKitConfig` takes one `AdAnalyticsTracker` and one `AdDiagnosticsTracker`. The app's analytics, an MMP revenue forwarder and an add-on package (pacing, resume ads) cannot all listen. A broadcast stream lets any number of listeners subscribe without the package knowing about them.

## API

```dart
sealed class AdEvent {
  final AdPlacement placement;

  /// Identifies one loaded ad across its events (request → load → impression → paid).
  final int adId;
  final DateTime timestamp;
}

final class AdRequested extends AdEvent {}
final class AdLoaded extends AdEvent { final Duration loadTime; }
final class AdLoadFailed extends AdEvent { final String message; final int? errorCode; }
final class AdImpression extends AdEvent {}
final class AdDisplayed extends AdEvent {}   // fullscreen on screen
final class AdClicked extends AdEvent {}
final class AdDismissed extends AdEvent {}   // fullscreen closed
final class AdPaid extends AdEvent { final AdRevenueValue revenue; }
final class AdDiagnostic extends AdEvent { final AdDiagnosticReport report; }

abstract final class AdmobKit {
  static Stream<AdEvent> get events;
}
```

```dart
AdmobKit.events.listen((event) => switch (event) {
  AdPaid(:final revenue) => analytics.logRevenue(revenue.value, revenue.currencyCode),
  AdLoadFailed(:final errorCode) => analytics.log('ad_fail', errorCode),
  _ => null,
});
```

`AdImpression` for banners and natives is its own plan: [inline-impressions.md](inline-impressions.md).

## Decisions

- **Lifetime:** the controller is top-level in `ad_session.dart`, like `_sessionInitState`, and outlives sessions. `dispose()` and a new `initialize()` do not close subscriptions, and listeners can subscribe before `initialize()` to receive splash events.
- **Delivery:** `StreamController<AdEvent>.broadcast()` (async). Events arrive in order one microtask later; a slow or throwing listener cannot break the engine's call stack. No replay.
- **Sealed events:** exhaustive `switch` in apps; a new event type in a later version is visible at compile time.
- **Diagnostics:** one `AdDiagnostic` event wrapping the existing `AdDiagnosticReport`. Its event types (`blackHoleSuspected`, `circuitBroken`, ...) name engine internals, so they stay a loose report documented as "for logging; may change" instead of becoming typed public events.
- **`adId`:** assigned when the engine starts a request. With `placementCapacities` above 1, two buffered ads share a placement; without an ID nobody can attribute an impression or revenue to its load. Plain incrementing `int`, unique per process.

## Implementation steps

1. `lib/src/domain/ad_events.dart`: the sealed hierarchy. Export from `admob_kit_flutter.dart`.
2. `ad_session.dart`: top-level `StreamController<AdEvent>.broadcast()`, an `@internal` `emitAdEvent(AdEvent)`, and the public getter on the facade.
3. **One emit path.** Engine and driver call `emitAdEvent` only. While the trackers are deprecated, `emitAdEvent` also forwards each event synchronously to `config.analytics` / `config.diagnostics` through one `switch`, so tracker timing stays as it is today. Removing the trackers in 0.2.0 deletes only that `switch`.
4. **`adId` plumbing:**
   - The engine assigns the ID in the load path (`ad_engine.dart` ~376, before `onAdRequested`) and passes it to `GoogleMobileAdsDriver.loadAd`.
   - The driver captures it in the listener closures it creates at load time (native ~145, banner ~274) for impression, click and paid events.
   - Fullscreen paid and click listeners are attached at show time (`showFullscreenAd`), so `AdCacheEntry` stores `adId` and the engine passes it to `showFullscreenAd`.
   - Inline ads handed to widgets carry the ID on `ManagedNativeAd` / `AdaptiveBannerAd`.
5. Replace the driver's `AdAnalyticsTracker? analytics` constructor parameter with the emit function.
6. Map every current call site:

   | Today | Event |
   |---|---|
   | `onAdRequested` (engine ~376) | `AdRequested` |
   | `onAdLoaded` (engine ~392) | `AdLoaded` |
   | `onAdFailedToLoad` (engine ~436) | `AdLoadFailed` |
   | `onAdDisplayed` (driver ~336) | `AdDisplayed` |
   | `onAdDismissed` (driver ~341) | `AdDismissed` |
   | `onAdClicked` (driver ~146, ~275, ~350) | `AdClicked` |
   | `onPaidEvent` (driver ~148, ~277, ~305) | `AdPaid` |
   | `onDiagnosticReport` (engine, 9 sites) | `AdDiagnostic` |

7. Mark deprecated: `AdmobKitConfig.analytics`, `AdmobKitConfig.diagnostics`, `AdAnalyticsTracker`, `AdDiagnosticsTracker`, with `@Deprecated('Use AdmobKit.events. Removed in 0.2.0.')`.

## Tests

- Every event type is emitted at its call site, in order, with the same `adId` from request to paid.
- Two buffered ads of one placement have different IDs.
- Subscriptions survive `dispose()` + `initialize()`; a listener added before `initialize()` sees splash events.
- A throwing listener does not affect loading or showing.
- Deprecated trackers still receive the same calls with the same timing (existing `analytics_callbacks_test.dart` passes).

## Docs

- `doc/recipes.md`: replace the "Analytics and diagnostics" tracker example with the stream.
- `doc/api.md`: events table; deprecation notes on the config fields.
- `doc/best-practices.md`: show rate = `AdImpression` / `AdLoaded` per placement.
- `doc/migration.md`: a "0.1.3: trackers to events" section.
- Skill sync, CHANGELOG.

## 0.2.0 follow-up

Delete `AdAnalyticsTracker`, `AdDiagnosticsTracker`, `AdmobKitConfig.analytics` / `diagnostics`, and the forwarding `switch` in `emitAdEvent`.
