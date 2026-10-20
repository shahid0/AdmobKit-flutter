import Foundation

/// Catalog mirrored by NativeAdTemplate with shared arrangements on both platforms.
enum NativeTemplate: String, CaseIterable {
    case rowWithLeadingIcon, rowWithTrailingIcon, rowLeadingCta
    case splitMediaLeft, splitMediaRight
    case cardContentTop, cardActionTop, cardContentTopTrailingIcon
    case feedMediaFirst, feedContentFirst, feedActionMiddle, feedTrailingIcon
    case feedMediaTopSideCta, feedContentTopSideCta
    case fullscreenMediaFirst, fullscreenContentFirst, fullscreenActionMiddle
    case fullscreenTrailingIcon, fullscreenMediaSideCta

    var factoryId: String { "admobKit.\(rawValue)" }
    var isCard: Bool { rawValue.hasPrefix("card") }
    var isRow: Bool { rawValue.hasPrefix("row") }
    var isSplit: Bool { self == .splitMediaLeft || self == .splitMediaRight }
    var isFullscreen: Bool { rawValue.hasPrefix("fullscreen") }
    var hasMedia: Bool { !isCard && !isRow }
    var trailingIcon: Bool { [Self.rowWithTrailingIcon, .cardContentTopTrailingIcon, .feedTrailingIcon, .fullscreenTrailingIcon].contains(self) }
    var sideAction: Bool { isRow || [Self.feedMediaTopSideCta, .feedContentTopSideCta, .fullscreenMediaSideCta].contains(self) }
    var leadingAction: Bool { self == .rowLeadingCta }
    var actionFirst: Bool { self == .cardActionTop }
    var actionMiddle: Bool { self == .feedActionMiddle || self == .fullscreenActionMiddle }
    var mediaFirst: Bool { isRow || [Self.feedMediaFirst, .feedMediaTopSideCta, .fullscreenMediaFirst, .fullscreenTrailingIcon, .fullscreenMediaSideCta].contains(self) }
}
