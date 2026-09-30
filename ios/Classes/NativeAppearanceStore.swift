import Flutter
import GoogleMobileAds
import UIKit

/// Engine-owned main-thread state, including reservations for pending SDK loads.
final class NativeAppearanceStore: NativeAppearanceHost {
  private var session: String?
  private var revision: Int64 = -1
  private var palettes: [String: NativePalette] = [:]
  private var views: [String: StyledNativeView] = [:]

  func startSession(sessionId: String) {
    clear()
    session = sessionId
  }

  func applyColors(sessionId: String, revision: Int64, renders: [String: NativePalette]) throws {
    guard session == sessionId else {
      throw PigeonError(code: "stale-session", message: "Native appearance session is no longer active", details: nil)
    }
    guard revision > self.revision else { return }
    self.revision = revision
    palettes = renders
    views = views.filter { renders[$0.key] != nil }
    for (id, view) in views {
      if let colors = renders[id] { view.apply(colors) }
    }
  }

  func endSession(sessionId: String) {
    if session == sessionId { clear() }
  }

  func clear() {
    session = nil
    revision = -1
    palettes.removeAll()
    views.removeAll()
  }

  func attach(_ view: NativeAdView, options: [AnyHashable: Any]?) {
    guard let session = session, options?["sessionId"] as? String == session,
      let id = options?["renderId"] as? String, let palette = palettes[id] else { return }
    let styled = StyledNativeView(view)
    views[id] = styled
    styled.apply(palette)
  }
}

/// Defaults are captured once. No SDK ad/view is strongly retained by the bridge.
private final class StyledNativeView {
  private weak var view: NativeAdView?
  private let background: UIColor?
  private let headline: UIColor?
  private let secondaryDefaults: [UIColor]
  private let ctaBackground: UIColor?
  private let ctaText: UIColor?

  init(_ view: NativeAdView) {
    self.view = view
    background = view.backgroundColor
    headline = (view.headlineView as? UILabel)?.textColor
    secondaryDefaults = Self.secondaryText(view).map { $0.textColor }
    ctaBackground = view.callToActionView?.backgroundColor
    ctaText = (view.callToActionView as? UIButton)?.titleColor(for: .normal)
  }

  func apply(_ colors: NativePalette) {
    guard let view = view else { return }
    view.backgroundColor = color(colors.background) ?? background
    (view.headlineView as? UILabel)?.textColor = color(colors.headline) ?? headline
    for (label, original) in zip(Self.secondaryText(view), secondaryDefaults) {
      label.textColor = color(colors.body) ?? original
    }
    view.callToActionView?.backgroundColor = color(colors.callToActionBackground) ?? ctaBackground
    (view.callToActionView as? UIButton)?.setTitleColor(color(colors.callToActionText) ?? ctaText, for: .normal)
  }

  private static func secondaryText(_ view: NativeAdView) -> [UILabel] {
    [view.bodyView, view.advertiserView, view.starRatingView, view.priceView].compactMap { $0 as? UILabel }
  }

  private func color(_ argb: Int64?) -> UIColor? {
    guard let argb = argb else { return nil }
    return UIColor(red: CGFloat((argb >> 16) & 255) / 255,
                   green: CGFloat((argb >> 8) & 255) / 255,
                   blue: CGFloat(argb & 255) / 255,
                   alpha: CGFloat((argb >> 24) & 255) / 255)
  }
}
