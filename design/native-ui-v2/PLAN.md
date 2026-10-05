# Native ad UI optimization plan

Status: implemented on Android and iOS; live iOS rendering verification remains pending. DSL is deferred to 1.0.0.

## Direction

Use the supplied YouTube-style reference as the visual direction: media first, a strong icon/copy row, quiet metadata, and one clear action. This is a native-ad component system, not a reproduction of YouTube's proprietary controls.

Optimize the existing native renderers and catalog. Preserve initialization, consent, queue, leases, freshness, presentation ownership and live NativeAdStyle.

## Policy boundaries

Google specifies truncation thresholds, not a mandatory line count: headline 25 characters, displayed body 90, CTA 15. Single-line defaults must respect those thresholds. Body is optional; do not partially show a protected passage just to fit one line.

CTA is required. Icon must render when provided. Rating/price are optional; never invent Free or a rating. Ad attribution and SDK AdChoices remain visible. Video requires an appropriate MediaView. Close controls must not overlap ad assets.

Source: [AdMob native advanced policy](https://support.google.com/admob/answer/6329638?hl=en). Apply its language-specific thresholds and current image/video rules during implementation.

## Shared identity row

Normal-size target:

- Leading icon around 64 logical pixels, square, aspect-fit; modest 10–12 radius.
- Headline around 16–17, semibold; one line where the protected text fits.
- Optional body around 13–14; one line only when permitted by the truncation rule.
- Metadata around 12–13, with a readable Ad badge at least the policy minimum.
- Approximately 4 vertical spacing between text rows and 8–12 between icon/copy.
- Aim for the three-row copy stack and 64-pixel icon to share a natural visual height.

Use coordinated font metrics, native content hugging and measured layout. Do not add blank spacers to stretch text, distort the icon, shrink text to force one line, or create a circular icon-width/text-height constraint.

When large fonts or protected copy require more height, grow the copy area and prioritize readability. Do not enlarge the icon indefinitely to chase every extra text line.

Missing icon: remove both its column and gap. Missing optional body/metadata: remove their views and corresponding gaps. The Ad badge remains even when every other metadata field is absent.

Metadata: Ad · 4.8 ★ · Free, only when those assets exist. Build separators between present fields. For content creatives, use supplied advertiser information where appropriate rather than app-store metadata. Rating/price use intrinsic width, not 44-pixel boxes.

## Compositions

### Media-first feed

Order: media -> icon/copy row -> CTA.

- No standalone attribution/rating header.
- Put attribution in the metadata row rather than alongside the headline.
- Use one full-width CTA, around 44–48 high, with the existing customizable radius.
- Keep media proportions intact; fit SDK creative without invented crops or controls.
- Keep the footer compact; allocate spare height to the media only when the chosen host is fullscreen.
- Do not make a content card taller merely to share a fullscreen footer.

### Three card compositions

- `cardContentTop`: identity -> full-width CTA.
- `cardActionTop`: full-width CTA -> identity.
- `cardContentTopTrailingIcon`: trailing-icon identity -> full-width CTA.

All share the same complete identity assets. Supplied video follows identity; action-top stays action-top even with video. Removed text-only, side-CTA, minimal-copy and split variants: they contradicted supplied-asset requirements or became duplicates at normal phone widths.

### Three feed compositions

- `feedMediaFirst`: media -> identity -> CTA.
- `feedContentFirst`: identity -> media -> CTA.
- `feedActionMiddle`: identity -> CTA -> media.

Order remains stable across widths. Missing optional assets can naturally make layouts converge; never add artificial filler to keep them different.

### Fullscreen

Use the same identity and action as feed layouts, with bounded media height. Three orders: `fullscreenMediaFirst`, `fullscreenContentFirst`, `fullscreenActionMiddle`. No duplicate trailing-icon or responsive side-action variants.

- No top cross or close control is built into a native template. Any dismissal belongs to the app's presentation flow, outside native assets (for example a bottom navigation control or an existing swipe-to-dismiss flow).
- SDK MediaView occupies the bounded remaining viewport with a predictable size for the device/placement.
- Footer uses natural content height, a roughly 64-pixel icon, quiet metadata and one CTA.
- Reserve the SDK AdChoices corner away from the close button, CTA and video controls.
- Portrait, square and landscape creatives fit rather than being stretched.
- Existing fullscreen ownership/activity gates remain unchanged.
- If required assets cannot fit the available bounds, do not clip them or trap the user.

Source: [iOS fullscreen guidance](https://developers.google.com/admob/ios/native/full-screen) and [Android fullscreen guidance](https://developers.google.com/admob/android/native/full-screen).

## Text fitting and sizing

An unconditional maxLines=1 switch is not the implementation.

1. Measure the protected text with actual platform font metrics and the available copy width.
2. Prefer one line when it fits.
3. For required text, allow sufficient native wrapping.
4. For optional body, show its complete text on one line or omit it; never clip it.
5. Preserve localized text, ellipsis boundaries and accessible font scaling.

Initial visual targets, not API guarantees:

| Composition | Normal-size target |
| --- | --- |
| Stacked identity + bottom CTA | Roughly 128–148 |
| Media-first feed | Media viewport + compact footer; depends on width and creative |
| Fullscreen | Bounded screen body, content-sized footer |

Do not commit smaller catalog heights until native geometry tests prove that protected copy, SDK media minimums and AdChoices clearance fit. Do not promise every creative fits the shortest target.

Keep one explicit sizing contract between the Flutter host and native views. If content-dependent height cannot be represented by the present catalog contract, design a narrowly scoped measured-size bridge using native framework measurement before changing host behavior. No post-frame resizing hacks, custom text-layout engine or alternative ad renderer.

## Implementation scope

1. Shared icon/copy/metadata/CTA rules on Android and iOS. Remove fixed metadata widths and asset-hiding assumptions.
2. Apply and validate the media-first feed and compact compositions.
3. Apply the same components to cards and fullscreen arrangements.
4. Use Pigeon to measure each native render at the host width/text scale before mounting; catalog heights are loading estimates, not inline constraints.
5. Test appearance changes/reset against the new geometry, without reloading ads.
6. Verify live test creatives on both platforms before approving the full catalog.

Do not add a public DSL, rewrite the ad engine, or add radius/style APIs beyond what is already supported in this UI update.

## Validation

- Widths 320/360/400, landscape, RTL and localized Ad badges.
- Wide-glyph and long copy, protected truncation boundaries, larger font settings.
- Missing icon/body/rating/price and long localized CTA/price.
- Content/app-install/video creatives with required assets intact.
- No dangling metadata separators or iOS broken constraints.
- No custom click handlers or clickable empty card background.
- Light/dark themes; radius/color update and reset; Android 2x/3x density.
- Fullscreen close, SDK AdChoices/media controls, route coverage and background/reactivation.

Image previews are composition references, not executable SDK renders or compliance approval. Runtime font measurement and real SDK assets decide the final dimensions.

## Reference files

- [Current nine-composition catalog, rendered from Android native views](catalog-rendered.png)
- [Feed direction](feed-reference.png)
- [Compact states](compact-reference.png)
- [Fullscreen direction](fullscreen-reference.png)
- [Generation prompts](PROMPTS.md)

## Visual review notes

The generated boards establish the composition, not pixel-perfect runtime geometry. Feed and fullscreen share the icon/copy/action hierarchy; older compact boards show side/bottom CTA exploration; the implemented catalog now uses full-width actions only, and supplied icons always render. No board introduces an attribution header, duplicate action or custom video control.

The fullscreen board's top cross is superseded: templates contain no close button, and the example app uses bottom Continue navigation outside the ad assets. Board labels are not runtime UI.

The generator varied the fictional icon artwork and rendered a filled Ad badge in some examples despite the outlined-badge prompt. Those are illustrative differences, not separate template specifications. Implementation should use the same badge treatment across compositions and the existing style controls. The SDK's actual AdChoices replaces every illustrative placeholder.

Real-creative acceptance remains separate: short sample copy does not exercise protected-text wrapping, accessibility or video sizing. Validate these before reducing catalog heights.
