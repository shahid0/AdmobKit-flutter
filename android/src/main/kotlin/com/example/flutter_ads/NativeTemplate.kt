package com.example.flutter_ads

/** Catalog mirrored by NativeAdTemplate; parity is checked in Dart tests. */
internal enum class NativeTemplate {
    small1, small2, small3, small4, small5, small6, small7, small8, medium1, medium2, medium3, medium4, medium5, medium6, large1, large2, large3, large4, large5, large6,
    fullscreen1, fullscreen2, fullscreen3, fullscreen4, fullscreen5;
    val factoryId get() = "admobKit.$name"
    val isSmall get() = name.startsWith("small")
    val isMedium get() = name.startsWith("medium")
    val isFullscreen get() = name.startsWith("fullscreen")
    val height get() = if (isSmall) 104 else if (isMedium) 160 else if (isFullscreen) 320 else 340
    val hasIcon get() = this !in setOf(small2, small5, small6, small7, small8)
    val hasMetadata get() = this !in setOf(small4, small6, small7, small8, medium1, medium2, medium5, medium6)
    val headlineLines get() = 2
    val bodyLines get() = if (isSmall && this !in setOf(small4, small5, small6, small7)) 1 else 2
}
