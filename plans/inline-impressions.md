# Plan: impression events for banners and natives

Release: 0.1.3. Depends on [events-stream.md](events-stream.md).

## Why

Fullscreen ads report `onAdDisplayed`. Banners and natives report nothing: the SDK's `onAdImpression` only sets a flag (`google_mobile_ads_driver.dart` ~145 for natives, ~274 for banners) that freshness checks use. Show rate, revenue per placement and pacing by impressions cannot be measured for inline ads, and `doc/best-practices.md` can only point at paid events.

## Behavior

- Every SDK `onAdImpression` emits `AdImpression(placement, adId)`. Keep setting `hasImpression`; freshness depends on it.
- Each refresh of an adaptive banner is a new impression from the SDK and emits a new event with the same `adId`. Document that `AdImpression` counts impressions, not ads.
- Fullscreen formats also emit `AdImpression` from their `FullScreenContentCallback.onAdImpression`, so one event means "the SDK counted an impression" for every format. `AdDisplayed` stays the fullscreen "on screen" event.
- Fullscreen natives are natives and use the native listener; no special case.

## Implementation steps

1. Native listener (~145): `onAdImpression: (_) { nativeAd.hasImpression = true; emit(AdImpression(...)); }`.
2. Banner listener (~274): same.
3. `createCallback` in `showFullscreenAd`: add `onAdImpression` emitting `AdImpression`.
4. The `adId` comes from the closures set up in the events plan.

## Tests

- A fake native and a fake banner firing `onAdImpression` emit one `AdImpression` each, with the load's `adId`.
- A banner refresh emits a second impression with the same `adId`.
- A fullscreen show emits `AdDisplayed` and `AdImpression`.
- Inline freshness/expiry tests still pass (`hasImpression` unchanged).

## Docs

- `doc/api.md`: `AdImpression` row, including the banner refresh note.
- `doc/best-practices.md`: show rate formula uses `AdImpression`.
- CHANGELOG.
