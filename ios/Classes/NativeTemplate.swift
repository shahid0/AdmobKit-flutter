import Foundation

/// Catalog mirrored by NativeAdTemplate with shared arrangements on both platforms.
enum NativeTemplate: String, CaseIterable {
    case cardContentTop, cardActionTop, cardContentTopTrailingIcon
    case feedMediaFirst, feedContentFirst, feedActionMiddle
    case fullscreenMediaFirst, fullscreenContentFirst, fullscreenActionMiddle

    var factoryId: String { "admobKit.\(rawValue)" }
    var isCard: Bool { rawValue.hasPrefix("card") }
    var isFullscreen: Bool { rawValue.hasPrefix("fullscreen") }
    var hasMedia: Bool { !isCard }
    var trailingIcon: Bool { self == .cardContentTopTrailingIcon }
    var actionFirst: Bool { self == .cardActionTop }
    var actionMiddle: Bool { self == .feedActionMiddle || self == .fullscreenActionMiddle }
    var mediaFirst: Bool { self == .feedMediaFirst || self == .fullscreenMediaFirst }
}
