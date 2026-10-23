# Plan: `show` returns `AdShowResult`

Release: 0.1.3 (additive, nothing breaks).

## Why

`AdmobKit.show` returns `void` and calls `onDismissed` on every exit path: shown, not ready, blocked by another ad, premium, consumed, failed. Apps and add-on packages (pacing, resume ads) cannot tell these apart, so a cooldown starts after an ad that never appeared.

## API

```dart
/// Outcome of [AdmobKit.show], delivered when the user flow continues.
enum AdShowResult {
  /// The ad was presented and then closed.
  shown,

  /// No fresh ad was buffered (includes a splash that settled without an ad).
  notReady,

  /// Another fullscreen ad owns the screen.
  busy,

  /// A `loadOnce` placement was already used.
  consumed,

  /// Ads are off: premium user, no consent, not initialized, or disposed.
  unavailable,

  /// The SDK refused to present the buffered ad.
  failed;

  bool get wasShown => this == shown;
}

static Future<AdShowResult> show(
  FullscreenPlacement placement, {
  VoidCallback? onDismissed,
  void Function(num amount, String type)? onRewardGranted,
  VoidCallback? onDisplayed,
});
```

- `onDismissed` stays. It is the simplest correct call for most transitions and cannot be misused across an `await`.
- `onRewardGranted` stays a callback. Google fires the reward while the ad is on screen; granting only after dismissal would lose rewards when the app is killed mid-ad.
- The Future completes at the same moment `onDismissed` runs, exactly once, on every path.

## Exit paths in `ad_engine.dart`

| Location | Today | Result |
|---|---|---|
| `show` → `!_adsAllowed` (~1032) | `onDismissed()` | `unavailable` |
| consumed `loadOnce`, nothing buffered or loading (~1038) | `onDismissed()` | `consumed` |
| `_settlingPresentations` or mutex locked (~1044) | `onDismissed()` | `busy` |
| cache miss / stale (~1074–1083) | `onDismissed()` | `notReady` |
| splash in flight → `_settleSplashAndPresent` (~1008) | settles later | `notReady` / `unavailable` when it fails, else the result of the inner `show` |
| `_mutex.tryAcquire` returns null (~1088) | `onDismissed()` | `busy` |
| `_driver == null` (~1110) | `finish()` | `failed` |
| `finish` after driver dismissal | `onDismissed()` | `shown` if the ad displayed, else `failed` |
| `catch` around `showFullscreenAd` (~1120) | `finish()` | `failed` |
| facade: `show` before `initialize` | `onDismissed()` | `unavailable` |

### Shown vs failed

The driver routes both a normal close and an Android show failure (`showFailed` → `finishTerminal`) to the same `onDismissed`. The engine records whether the driver's `onDisplayed` fired before `finish`:

```dart
var displayed = false;
// driver onDisplayed: displayed = true; then the existing gated onDisplayed?.call()
// finish(): complete(displayed ? AdShowResult.shown : AdShowResult.failed)
```

Set `displayed` before the existing `!finished && _adsAllowed` gate, so a premium flip during the ad still reports `shown`.

### Dispose during an open ad

`dispose()` force-releases the mutex but the platform ad stays on screen; its dismiss callback still reaches `finish`, so the Future completes on user dismissal. Cover this with a test instead of adding a dispose path.

## Implementation steps

1. Add `AdShowResult` to `lib/src/domain/ad_placements.dart` (next to `AdPlacementState`) and export it.
2. `AdEngine.show` and `_settleSplashAndPresent`: create a `Completer<AdShowResult>`, replace each `onDismissed?.call(); return;` with one local `complete(result)` that calls `onDismissed` and then completes. Return the future.
3. `AdSession.show` and `AdmobKit.show`: return the engine future; the pre-initialize branch returns `Future.value(AdShowResult.unavailable)`.
4. `AdPaywallGuard` keeps using `onDismissed`; no change.

## Tests

One test per row of the table, plus:
- the Future completes exactly once and after `onDismissed`;
- a splash that is loading completes later with `shown`;
- an Android show failure (driver dismisses without `onDisplayed`) gives `failed`;
- dispose while an ad is open still completes on dismissal;
- the existing `onDismissed` tests pass unchanged.

## Docs

- `doc/api.md`: signature and enum.
- `doc/recipes.md`: one example using the result (start a cooldown only when `wasShown`). Keep `onDismissed` as the main pattern; mention a `mounted` check after `await` in widgets.
- `doc/design-decisions.md`: why the reward stays a callback and why `onDismissed` stays.
- Sync the skill (`dart run tool/sync_skill.dart`), CHANGELOG.
