# Troubleshooting

Use public status, logs, tracker events, and Ad Inspector first.
You do not need to inspect internal source to diagnose normal integration problems.

## No ads appear

1. Check the AdMob app ID in the platform file. Check the unit IDs separately.
2. Use the correct platform and format test unit IDs.
3. Check that `initialize` was called before registration or widget mounting.
4. Check initialization errors and `initializationState`.
5. Check premium entitlement and consent configuration.
6. Check network access, VPN filters, DNS filters, and ad blockers.
7. Check layout bounds and widget activity.
8. Open Ad Inspector and inspect the reported load error.

Do not disable consent or add timers to force ads to load.
No fill is a normal unavailable-ad result. A loaded test ad does not guarantee future production fill.

```dart
void inspectAdIntegration() {
  AdmobKit.openAdInspector((error) {
    if (error != null) debugPrint('Ad Inspector: $error');
  });
}
```

## A first ad is missing

`canRequestAds == false` can mean initialization is pending, not that consent was denied.
Do not return early from startup on that snapshot.
Use `waitFor` for a waiting flow, or mount the inline widget. Both handle eligibility resolution.
Registration during initialization is retained. Registration before initialization throws `StateError`.

`show` is not a download wait for normal placements. Register reachable placements early.
Use `waitFor` if the feature explicitly needs a ready/unavailable decision.
A splash placement can wait for an already pending load. It does not guarantee immediate dismissal.

## A wait returns false

False means no usable buffered ad at the decision point.
It can result from denial, failure, timeout, premium access, disposal, or consumed `loadOnce` state.
Check initialization state and diagnostic reports to distinguish those causes.
An ad timeout starts after eligibility resolution. It is not a total initialization deadline.
Do not poll `isReady` or add a custom retry loop.

## Banner errors

Use `AdBannerView` for normal banner loading.
An explicit banner wait or state query needs `BannerLayout` with actual width and orientation.
Registration alone cannot know a banner's layout.
Requests for different layouts do not share readiness.
Do not impose an estimated banner height. Inline banners reserve their configured maximum height.

## Native layout errors

Use at least 320 logical pixels of bounded width.
For inline templates, let content determine height. Do not use `template.height` as a fixed loaded height.
For fullscreen templates, provide bounded height and enough room for actual text and media.
If the available space is insufficient, show normal app content instead of that native placement.
Do not hide required SDK assets or clip them to suppress an error.
Read the [known native production limit](native-ads.md#production-limit).

## Ads in hidden pages

Check `active`, ancestor `Visibility`, and `TickerMode`.
Pass selected-page activity for retained `PageView`, `TabBarView`, or custom lazy hosts.
Mounting alone does not establish viewport visibility.
Do not acquire or release presentation locks in app code.

## Premium access changes

The `isPremium` callback supplies current entitlement; it does not notify widgets.
Rebuild ad hosts when entitlement changes. The library checks entitlement at request and presentation boundaries.
Do not call package-wide `dispose` on each screen or purchase state change.

## Configuration changes

An active session keeps its first initialization configuration.
For a new session configuration, dispose and initialize again, then register reachable placements.
Use unique IDs for different formats, templates, unit IDs, or banner sizing.
For native appearance only, use `setNativeStyle` and await its result.

## Privacy changes and status streams

`showPrivacyOptionsForm` refreshes eligibility and pending loading.
It cannot display over an active fullscreen ad.
A true form result does not mean ads are allowed.
A failed requirement query is not a false requirement decision; retry the settings query.
An unknown UMP requirement is also reported as an error, not as a not-required result.

A placement stream can end when privacy changes or the session is disposed.
Reattach diagnostic streams after an initialization-state change.
Normal ad widgets handle session changes themselves.

## Information for a bug report

Include the package version, platform, placement type, template or banner sizing,
initialization state, whether test IDs reproduce the issue, and relevant diagnostic events.
Remove secrets and user identifiers from logs. Include host bounds and activity state for layout problems.
If supported usage still fails, report a package defect. Do not work around it through private SDK objects.
