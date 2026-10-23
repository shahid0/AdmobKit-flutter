# Plans

Maintainer-only; excluded from the published package.

## 0.1.3 (no breaking changes)

1. [Show result](show-result.md): `show` returns `Future<AdShowResult>`. Independent; can land first.
2. [Events stream](events-stream.md): `AdmobKit.events`; trackers deprecated.
3. [Inline impressions](inline-impressions.md): `AdImpression` for banners and natives. Needs the stream.

## 0.2.0

- Remove the deprecated `AdAnalyticsTracker`, `AdDiagnosticsTracker` and `AdmobKitConfig.analytics` / `diagnostics`.
- Any other breaking change goes here instead of 0.1.3.
