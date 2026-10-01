import Foundation

/// Catalog mirrored by NativeAdTemplate with shared arrangements on both platforms.
enum NativeTemplate: String, CaseIterable {
    case rowWithLeadingIcon, rowTextOnly, rowWithTrailingIcon, rowExpandedText
    case rowTextOnlyExpanded, rowMinimalText, rowLeadingCta, rowLeadingCtaCompact
    case splitMediaLeft, splitMediaRight, cardContentTop, cardActionTop
    case cardCleanContentTop, cardCleanActionTop
    case feedMediaFirst, feedContentFirst, feedActionMiddle, feedTrailingIcon
    case feedMediaTopSideCta, feedContentTopSideCta
    case fullscreenMediaFirst, fullscreenContentFirst, fullscreenTrailingIcon
    case fullscreenMediaSideCta, fullscreenActionMiddle

    var factoryId: String { "admobKit.\(rawValue)" }
    var isSmall: Bool { rawValue.hasPrefix("row") }
    var isMedium: Bool { rawValue.hasPrefix("split") || rawValue.hasPrefix("card") }
    var isFullscreen: Bool { rawValue.hasPrefix("fullscreen") }
    var hasIcon: Bool { ![Self.rowTextOnly, .rowTextOnlyExpanded, .rowMinimalText, .rowLeadingCta, .rowLeadingCtaCompact].contains(self) }
    var hasMetadata: Bool { ![Self.rowExpandedText, .rowMinimalText, .rowLeadingCta, .rowLeadingCtaCompact, .splitMediaLeft, .splitMediaRight, .cardCleanContentTop, .cardCleanActionTop].contains(self) }
    var headlineLines: Int { 2 }
    var bodyLines: Int { isSmall && ![Self.rowExpandedText, .rowTextOnlyExpanded, .rowMinimalText, .rowLeadingCta].contains(self) ? 1 : 2 }
}
