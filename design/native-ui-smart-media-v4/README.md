# Smart-media layouts

`reference.png` is the generated design reference. `PROMPTS.md` preserves the exact generation prompt.

`native-smart-media.png` is the production Android renderer fixture, with only SDK creative/binding simulated. `native-catalog.png` includes all 19 layouts. Captions are outside runtime ad views; fixture creatives are not bundled with the package. SDK AdChoices is absent from these simulated fixtures, not replaced by an app control.

The two restored layouts keep media and content side by side at widths >=320 logical pixels. The SDK media viewport is 120x120 pixels with aspect-fit content; the content column has a 40-pixel icon beside headline/body, metadata below that identity, then a column-width CTA. Ad height is native-measured, not fixed. Large text and long required copy can grow the ad without stretching the media viewport or changing its composition. Android and iOS share these arrangements; all existing 17 layouts are retained.
