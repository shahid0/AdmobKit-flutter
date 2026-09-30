import Foundation

/// Catalog mirrored by NativeAdTemplate; arrangements use the upstream iOS ordering.
enum NativeTemplate: String, CaseIterable {
    case small1, small2, small3, small4, small5, small6, small7, small8, medium1, medium2, medium3, medium4, medium5, medium6, large1, large2, large3, large4, large5, large6
    case fullscreen1, fullscreen2, fullscreen3, fullscreen4, fullscreen5
    var factoryId: String { "admobKit.\(rawValue)" }
    var isSmall: Bool { rawValue.hasPrefix("small") }
    var isMedium: Bool { rawValue.hasPrefix("medium") }
    var isFullscreen: Bool { rawValue.hasPrefix("fullscreen") }
    var hasIcon: Bool { ![Self.small2, .small5, .small6, .small7, .small8].contains(self) }
    var hasMetadata: Bool { ![Self.small4, .small6, .small7, .small8, .medium1, .medium2, .medium5, .medium6].contains(self) }
    var tallButton: Bool { [Self.small3, .small4, .small5, .small6, .small7].contains(self) }
    var bodyLines: Int { self == .small4 || self == .small6 || isMedium || isFullscreen ? 2 : 1 }
}
