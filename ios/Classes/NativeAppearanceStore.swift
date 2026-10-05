import Flutter
import GoogleMobileAds
import UIKit

/// Engine-owned main-thread state, including reservations for pending SDK loads.
final class NativeAppearanceStore: NativeAppearanceHost {
  private var session: String?
  private var revision: Int64 = -1
  private var palettes: [String: NativeStyleData] = [:]
  private var views: [String: StyledNativeView] = [:]

  func startSession(sessionId: String) {
    clear()
    session = sessionId
  }

  func applyStyle(sessionId: String, revision: Int64, renders: [String: NativeStyleData]) throws {
    guard session == sessionId else {
      throw PigeonError(code: "stale-session", message: "Native appearance session is no longer active", details: nil)
    }
    guard revision > self.revision else { return }
    guard renders.values.allSatisfy({ style in
      guard let radius = style.callToActionCornerRadius else { return true }
      return radius.isFinite && radius >= 0
    }) else {
      throw PigeonError(code: "invalid-style", message: "CTA radius must be finite and non-negative", details: nil)
    }
    self.revision = revision
    palettes = renders
    views = views.filter { renders[$0.key] != nil }
    for (id, view) in views {
      if let style = renders[id] { view.apply(style) }
    }
  }

  func endSession(sessionId: String) {
    if session == sessionId { clear() }
  }

  func layoutNativeAd(sessionId: String, renderId: String, request: NativeLayoutRequest) throws -> Double {
    guard session == sessionId, let styled = views[renderId] else {
      throw PigeonError(code: "released-render", message: "Native render is no longer available", details: nil)
    }
    let height = try styled.configure(request)
    if let palette = palettes[renderId] { styled.apply(palette) }
    return height
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
  private let ctaRadius: CGFloat?

  init(_ view: NativeAdView) {
    self.view = view
    background = view.backgroundColor
    headline = (view.headlineView as? UILabel)?.textColor
    secondaryDefaults = Self.secondaryText(view).map { $0.textColor }
    ctaBackground = view.callToActionView?.backgroundColor
    ctaText = (view.callToActionView as? UIButton)?.titleColor(for: .normal)
    ctaRadius = view.callToActionView?.layer.cornerRadius
  }

  func configure(_ request: NativeLayoutRequest) throws -> Double {
    guard let view = view as? NativeTemplateView, let configure = view.configure else {
      throw PigeonError(code: "released-render", message: "Native view was released", details: nil)
    }
    return try configure(request)
  }

  func apply(_ style: NativeStyleData) {
    guard let view = view else { return }
    view.backgroundColor = color(style.background) ?? background
    (view.headlineView as? UILabel)?.textColor = color(style.headline) ?? headline
    for (label, original) in zip(Self.secondaryText(view), secondaryDefaults) {
      label.textColor = color(style.body) ?? original
    }
    (view as? NativeTemplateView)?.separators.forEach {
      $0.textColor = color(style.body) ?? NativeTemplateStyle.secondary
    }
    view.callToActionView?.backgroundColor = color(style.callToActionBackground) ?? ctaBackground
    (view.callToActionView as? UIButton)?.setTitleColor(color(style.callToActionText) ?? ctaText, for: .normal)
    if let original = ctaRadius {
      view.callToActionView?.layer.cornerRadius = min(style.callToActionCornerRadius.map { CGFloat($0) } ?? original,
        (view.callToActionView?.bounds.height ?? 0) / 2)
    }
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
