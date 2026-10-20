# Built-in image generation prompts

## Same-row CTA board

Use case: ui-mockup
Asset type: high-fidelity mobile native-ad component reference board for a Flutter AdMob library.
Primary request: redesign six useful native ad compositions with genuine SAME-ROW CTA buttons. Premium restrained YouTube/Google-feed quality, practical native Android/UIKit components, compact efficient height, no decorative chrome. This is a design reference before implementation.
Composition: portrait comparison board, TWO COLUMNS, THREE ROWS, six clearly separated examples. Outside each ad place ONLY its exact API label, in the stated reading order. Render all examples at comparable 360-logical-pixel width. Label and actual composition MUST match:
1 rowWithLeadingIcon: one horizontal row [64px square icon, vertical text identity, compact CTA on right].
2 rowWithTrailingIcon: one horizontal row [vertical text identity, 64px square icon, compact CTA on right]. Icon trails identity; CTA remains rightmost.
3 rowLeadingCta: one horizontal row [compact CTA on left, 64px square icon, vertical text identity].
4 feedMediaTopSideCta: landscape hero media ABOVE one horizontal footer [64px icon, vertical text identity, compact right CTA]. NO second or bottom CTA.
5 feedContentTopSideCta: one horizontal header [64px icon, vertical text identity, compact right CTA] ABOVE landscape hero media. NO bottom CTA.
6 fullscreenMediaSideCta: bounded portrait hero creative ABOVE one horizontal footer [64px icon, vertical text identity, compact right CTA]. No top X/close, no second CTA. Hero fills height using a portrait creative, not a landscape poster floating in white space.
Identity exact content: headline "Focus timer" in 17px semibold, body "Stay focused" in 14px grey STRICTLY ONE LINE, metadata "Ad · 4.5 ★ · Free" in 12px. Ad is a small readable rectangular outlined attribution badge within metadata, NOT a separate top row. Use exact CTA "Install" in compact dark rounded rectangle, approximately 76 by 44 logical pixels, default radius 8, NOT a capsule. Icon 64 square softly rounded, dark green with white simple C letter. Icon aligns naturally with three-line text stack. Content insets 8, icon-text spacing10, text row gap4, CTA gap8. Reserve upper-right space for SDK-owned AdChoices; do not draw invented interactive controls.
Style: white/light cards radius12, ink #0f0f0f and muted grey text, neutral pale board background. Media muted green nature/productivity visual with clean supplied creative copy only "Find your focus." Icons and media belong to the advertiser fixture, not app headings.
Constraints: EXACT API labels outside the ads; no title, subtitles, explanatory text, "compact", "short copy", "clarity", Sponsored, Watch, overflow menu, custom mute or fake AdChoices. No two-line body. Every example has exactly one CTA on the specified SAME ROW as identity, no full-width action beneath it. Fullscreen no close button. Six different specified geometries, not repeated cards relabeled. Flat straight-on crisp shippable UI, no phones, perspective, gradients on buttons or excessive blank padding.

## Targeted correction

Change only feedContentTopSideCta media to a landscape 16:9 viewport matching feedMediaTopSideCta. Preserve the same-row header, all five other layouts, labels, colors and body copy. Collapse the card's natural height without filler.

## Trailing-icon board

Use case: ui-mockup. Asset: native-ad UI design reference board, high-fidelity straight-on implementable Android/UIKit UI. TWO side-by-side native ad examples, same360px logical width, outside each ONLY exact API label.
Left label "feedTrailingIcon": white content-sized card. TOP identity row with text LEFT and 64px square icon RIGHT (icon trails text), then LANDSCAPE16:9 hero creative, then exactly one full-width dark CTA "Install" default8px radius. Identity exactheadline "Focus timer"17pxsemibold; exactbody "Stay focused"14pxgrey strictlyONEline; metadata "Ad · 4.5 ★ · Free"12pxgrey with outlined rectangular Adbadge. Icon darkgreen with whiteC,10pxradius. Hero calm woodland/lake mutedgreen, suppliedcreative "Find your focus." No arbitrary new controls.
Right label "fullscreenTrailingIcon": bounded fullscreen card with PORTRAIT hero creative FIRST, followed by compact identity row with text LEFT and64pxicon RIGHT, then full-width darkCTA "Install". The icon MUST be right of the identity text, unlike a leading-icon default. Same typography/body/metadata. Hero shows portrait woodland path so fills allocated media height instead of landscape letterboxing; don't add app chrome or top closecross.
Style: refined Google/YouTube native quality, whitecard modest12pxcorners, inset8, gap8, identitygap10,textgap4, efficient natural footer. SDK owns AdChoices top-right; reserve its corner, don't draw custom badge/control for it. No headerstrip for Adbadge. No capsules, oversizedpadding, fakebuttons, two-linebody, extraSponsored/Watchtext. Exactmatchinglabelsandlayouts. Palegrayboardbackground; no title, footnotes, phones, perspective or watermark.
