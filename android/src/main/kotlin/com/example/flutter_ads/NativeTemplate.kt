package com.example.flutter_ads

/** Catalog mirrored by NativeAdTemplate; parity is checked in Dart tests. */
internal enum class NativeTemplate {
    rowWithLeadingIcon, rowTextOnly, rowWithTrailingIcon, rowExpandedText,
    rowTextOnlyExpanded, rowMinimalText, rowLeadingCta, rowLeadingCtaCompact,
    splitMediaLeft, splitMediaRight, cardContentTop, cardActionTop,
    cardCleanContentTop, cardCleanActionTop,
    feedMediaFirst, feedContentFirst, feedActionMiddle, feedTrailingIcon,
    feedMediaTopSideCta, feedContentTopSideCta,
    fullscreenMediaFirst, fullscreenContentFirst, fullscreenTrailingIcon,
    fullscreenMediaSideCta, fullscreenActionMiddle;

    val factoryId get() = "admobKit.$name"
    val isSmall get() = name.startsWith("row")
    val isMedium get() = name.startsWith("split") || name.startsWith("card")
    val isFullscreen get() = name.startsWith("fullscreen")
    val height get() = if (isSmall) 104 else if (isMedium) 160 else if (isFullscreen) 320 else 340
    val hasIcon get() = this !in setOf(rowTextOnly, rowTextOnlyExpanded, rowMinimalText, rowLeadingCta, rowLeadingCtaCompact)
    val hasMetadata get() = this !in setOf(rowExpandedText, rowMinimalText, rowLeadingCta, rowLeadingCtaCompact, splitMediaLeft, splitMediaRight, cardCleanContentTop, cardCleanActionTop)
    val headlineLines get() = 2
    val bodyLines get() = if (isSmall && this !in setOf(rowExpandedText, rowTextOnlyExpanded, rowMinimalText, rowLeadingCta)) 1 else 2
}
