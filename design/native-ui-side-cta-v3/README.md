# Same-row CTA redesign

The generated images are composition references, not SDK renders or compliance approval.

- [Same-row CTA compositions](side-cta-reference.png): `rowWithLeadingIcon`, `rowWithTrailingIcon`, `rowLeadingCta`, `feedMediaTopSideCta`, `feedContentTopSideCta`, `fullscreenMediaSideCta`.
- [Trailing-icon compositions](trailing-icon-reference.png): `feedTrailingIcon`, `fullscreenTrailingIcon`.
- [Native-rendered same-row fixtures](side-cta-rendered.png) and [all 17 native-rendered fixtures](catalog-rendered.png): production Android composition with simulated SDK creative/binding, not live AdMob creatives.

Keep the existing nine layouts. Restore these eight useful arrangements, for 17 total. Do not silently turn side actions into bottom actions. Native text wraps at its real font size; optional body appears only if its complete text fits one line. Native measurement determines height before mounting. Missing assets collapse without filler. Supplied icons and video remain rendered; SDK asset registration, click handling, and AdChoices stay unchanged.

Same-row actions have intrinsic width with a minimum of 76 logical pixels, capped at one third of available row width. Their text can wrap at that width; minimum height is 44 (48 fullscreen). Identity gets the remaining width, not a hardcoded text height. Icons remain 64 square. CTA spacing is 8, icon spacing 10, text spacing 4. Existing colors/radius APIs apply unchanged.

The reference images guide hierarchy and placement. Runtime feed media uses a landscape 16:9 viewport; fullscreen media uses bounded remaining height, with SDK aspect-fit. Reference creative text is test data only, never production UI copy. Required long headline/CTA copy wraps; never truncate it just to preserve the shortest visual target.

Generated with the built-in image tool; exact prompts are in [PROMPTS.md](PROMPTS.md).
