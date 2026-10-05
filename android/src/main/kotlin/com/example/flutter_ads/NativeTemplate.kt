package com.example.flutter_ads

/** Catalog mirrored by NativeAdTemplate; parity is checked in Dart tests. */
internal enum class NativeTemplate {
    rowWithLeadingIcon, rowWithTrailingIcon, rowLeadingCta,
    splitMediaLeft, splitMediaRight,
    cardContentTop, cardActionTop, cardContentTopTrailingIcon,
    feedMediaFirst, feedContentFirst, feedActionMiddle, feedTrailingIcon,
    feedMediaTopSideCta, feedContentTopSideCta,
    fullscreenMediaFirst, fullscreenContentFirst, fullscreenActionMiddle,
    fullscreenTrailingIcon, fullscreenMediaSideCta;

    val factoryId get() = "admobKit.$name"
    val isCard get() = name.startsWith("card")
    val isRow get() = name.startsWith("row")
    val isSplit get() = this == splitMediaLeft || this == splitMediaRight
    val isFullscreen get() = name.startsWith("fullscreen")
    val height get() = if (isRow) 80 else if (isSplit) 160 else if (isCard) 132 else if (isFullscreen) 320 else if (sideAction) 280 else 340
    val hasMedia get() = !isCard && !isRow
    val trailingIcon get() = this in setOf(rowWithTrailingIcon, cardContentTopTrailingIcon, feedTrailingIcon, fullscreenTrailingIcon)
    val sideAction get() = isRow || this in setOf(feedMediaTopSideCta, feedContentTopSideCta, fullscreenMediaSideCta)
    val leadingAction get() = this == rowLeadingCta
    val actionFirst get() = this == cardActionTop
    val actionMiddle get() = this == feedActionMiddle || this == fullscreenActionMiddle
    val mediaFirst get() = isRow || this in setOf(feedMediaFirst, feedMediaTopSideCta, fullscreenMediaFirst, fullscreenTrailingIcon, fullscreenMediaSideCta)
}
