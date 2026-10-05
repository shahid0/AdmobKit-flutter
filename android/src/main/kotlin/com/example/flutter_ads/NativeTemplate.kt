package com.example.flutter_ads

/** Catalog mirrored by NativeAdTemplate; parity is checked in Dart tests. */
internal enum class NativeTemplate {
    cardContentTop, cardActionTop, cardContentTopTrailingIcon,
    feedMediaFirst, feedContentFirst, feedActionMiddle,
    fullscreenMediaFirst, fullscreenContentFirst, fullscreenActionMiddle;

    val factoryId get() = "admobKit.$name"
    val isCard get() = name.startsWith("card")
    val isFullscreen get() = name.startsWith("fullscreen")
    val height get() = if (isCard) 132 else if (isFullscreen) 320 else 340
    val hasMedia get() = !isCard
    val trailingIcon get() = this == cardContentTopTrailingIcon
    val actionFirst get() = this == cardActionTop
    val actionMiddle get() = this == feedActionMiddle || this == fullscreenActionMiddle
    val mediaFirst get() = this == feedMediaFirst || this == fullscreenMediaFirst
}
