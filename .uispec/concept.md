# Concept: Architectural Clarity for High-Agency Builders

> "An architectural instrument crafted with structural lightness, mathematical precision, and tactile warmth—eradicating generic SaaS templates and noisy dark cards."

- **Committed Date**: 2026-09-09
- **UI Design Class**: **Class 1 (Instrumental Precision)** combined with **Class 2 (Tactile Humanist)** calibrated for an Architectural Light Theme.
- **Target Visual Telemetry Ratio**: 65% telemetry & spatial grouping / 35% text.

---

## 1. The Creative Philosophy: Show, Don't Tell — But Make It Beautiful

1. **Precision Structural Surface**: The screen is not an ungrounded sheet of blinding paper (`#FFFFFF`), nor is it a muddy dark box. It is an architectural drafting canvas in Warm Architectural Chalk (`#F8F9FA`) with elevated Pure White (`#FFFFFF`) card planes defined by 1px hairline zinc borders (`#E2E8F0`).
2. **Visual Telemetry over Verbose Sentences**:
   - Statuses are expressed via pulsing emerald (`#059669`), amber (`#D97706`), or rose (`#DC2626`) beacons with monospace tabular tags.
   - Progress is communicated via segmented linear tracks, circular ring meters, and sparklines—never raw paragraph disclaimers.
3. **Seamless Monetization Ergonomics**:
   - Ads are treated as first-class citizens of the interface grid, styled with identical 16px corner rounding, 1px zinc borders, and soft shadows as organic task cards.
   - Zero cumulative layout shift (CLS). Ads occupy strictly reserved layout envelopes.

---

## 2. The Absolute Forbidden List

The interface strictly forbids:
1. ❌ **Flat `#FFFFFF` Screen Canvases**: The app canvas ground must always be `#F8F9FA` (Architectural Chalk) to provide depth contrast for elevated `#FFFFFF` cards.
2. ❌ **AI Purple/Indigo Gradients & Blobs**: No generic neon violet gradients or ambient floating blur spheres.
3. ❌ **Centering as a Crutch**: Layouts must feature intentional left-aligned scanning hierarchy with right-aligned tabular telemetry.
4. ❌ **Non-Concentric Corner Radii**: Nested child elements must obey $r_{\text{inner}} = r_{\text{outer}} - \text{padding}$.
5. ❌ **Unconstrained Flex Overflows**: All flex rows containing dynamic text must declare truncation defenses (`Flexible`/`Expanded` + `TextOverflow.ellipsis`).
6. ❌ **Missing Active Press States**: All interactive touch surfaces must compress to `scale(0.97)` on tap with instant release.
7. ❌ **Proportional Numbers in Timers & Metrics**: All counters, timers, and statistics must use tabular monospace numerals (`fontFeatures: [FontFeature.tabularFigures()]`).
8. ❌ **Raw Unstyled Ad Placements**: Raw AdMob banners floating over random content are banned. Every ad is framed in an architectural surface card.
