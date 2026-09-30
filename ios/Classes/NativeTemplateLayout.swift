// Arrangements adapted from flutter_monetization_kit, MIT (c) 2026 Hamza.
// See THIRD_PARTY_NOTICES.md. SDK assets and clicks remain SDK-owned.
import GoogleMobileAds
import UIKit

/// Stack-based inline compositions; no ad loading, caching or platform channels.
final class NativeTemplateLayout {
  private let template: NativeTemplate
  init(template: NativeTemplate) { self.template = template }

  private func stack(_ axis: NSLayoutConstraint.Axis, _ views: [UIView], spacing: CGFloat = 8) -> UIStackView {
    let result = UIStackView(arrangedSubviews: views)
    result.axis = axis
    result.spacing = spacing
    result.translatesAutoresizingMaskIntoConstraints = false
    return result
  }

  private func label(_ value: String?, size: CGFloat, lines: Int = 1) -> UILabel {
    let label = UILabel()
    label.text = value
    label.font = .systemFont(ofSize: size)
    label.textColor = size >= 14 ? .black : .darkGray
    label.numberOfLines = lines
    label.lineBreakMode = .byTruncatingTail
    label.translatesAutoresizingMaskIntoConstraints = false
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
  }

  private func pin(_ child: UIView, to parent: UIView, inset: CGFloat = 0) {
    child.translatesAutoresizingMaskIntoConstraints = false
    parent.addSubview(child)
    NSLayoutConstraint.activate([
      child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
      child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
      child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
      child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
    ])
  }

  func build(_ ad: NativeAd) -> NativeAdView {
    let view = NativeAdView()
    view.backgroundColor = .white
    view.layer.cornerRadius = 8

    let badge = label("Ad", size: 10)
    badge.textColor = .black
    badge.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
    badge.textAlignment = .center
    let choices = AdChoicesView()
    view.adChoicesView = choices
    let attribution = stack(.horizontal, [badge, UIView(), choices])
    attribution.alignment = .center
    NSLayoutConstraint.activate([
      attribution.heightAnchor.constraint(equalToConstant: 24),
      badge.widthAnchor.constraint(equalToConstant: 24),
      badge.heightAnchor.constraint(equalToConstant: 16),
      choices.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
      choices.heightAnchor.constraint(equalToConstant: 24)
    ])

    let headline = label(ad.headline, size: template.isFullscreen ? 17 : 14, lines: template.isFullscreen ? 2 : 1)
    headline.font = .boldSystemFont(ofSize: template.isFullscreen ? 17 : 14)
    let body = label(ad.body, size: 12, lines: template.bodyLines)
    view.headlineView = headline
    view.bodyView = body
    let details = stack(.vertical, [headline, body], spacing: 0)
    if template.hasMetadata {
      let advertiser = label(ad.advertiser, size: 10)
      let rating = label(ad.starRating.map { "\($0) ★" }, size: 10)
      let price = label(ad.price, size: 10)
      view.advertiserView = advertiser
      view.starRatingView = rating
      view.priceView = price
      let metadata = stack(.horizontal, [advertiser, rating, price], spacing: 4)
      metadata.heightAnchor.constraint(equalToConstant: 16).isActive = true
      details.addArrangedSubview(metadata)
    }

    let button = UIButton(type: .custom)
    button.setTitle(ad.callToAction, for: .normal)
    button.titleLabel?.font = .boldSystemFont(ofSize: 12)
    button.titleLabel?.lineBreakMode = .byTruncatingTail
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = UIColor(red: 0.13, green: 0.59, blue: 0.95, alpha: 1)
    button.layer.cornerRadius = 8
    button.isHidden = ad.callToAction?.isEmpty != false
    // Google Mobile Ads handles asset clicks, never application targets.
    button.isUserInteractionEnabled = false
    view.callToActionView = button
    let cta = UIView()
    pin(button, to: cta)

    func icon(_ size: CGFloat) -> UIImageView {
      let image = UIImageView(image: ad.icon?.image)
      image.contentMode = .scaleAspectFit
      image.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        image.widthAnchor.constraint(equalToConstant: size),
        image.heightAnchor.constraint(equalToConstant: size)
      ])
      view.iconView = image
      return image
    }
    func content(sideButton: Bool = false, iconRight: Bool = false) -> UIStackView {
      var children: [UIView] = [details]
      if template.hasIcon {
        let size: CGFloat = template.isFullscreen ? 56 : 48
        if iconRight { children.append(icon(size)) } else { children.insert(icon(size), at: 0) }
      }
      if sideButton {
        children.append(cta)
        cta.widthAnchor.constraint(equalToConstant: 84).isActive = true
        if !template.tallButton { cta.heightAnchor.constraint(equalToConstant: 40).isActive = true }
      }
      let row = stack(.horizontal, children)
      row.alignment = .center
      if sideButton && template.tallButton {
        NSLayoutConstraint.activate([
          cta.topAnchor.constraint(equalTo: row.topAnchor),
          cta.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
      }
      return row
    }
    func media() -> MediaView {
      let media = MediaView()
      media.mediaContent = ad.mediaContent
      media.contentMode = .scaleAspectFit
      view.mediaView = media
      media.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
      return media
    }

    let layout: UIStackView
    if template.isFullscreen {
      let row = content()
      let media = media()
      cta.heightAnchor.constraint(equalToConstant: 52).isActive = true
      if template != .fullscreen4 { row.heightAnchor.constraint(equalToConstant: 96).isActive = true }
      switch template {
      case .fullscreen1: layout = stack(.vertical, [row, media, cta])
      case .fullscreen2: layout = stack(.vertical, [cta, row, media])
      // Dedicated bottom content keeps SDK video controls unobstructed.
      case .fullscreen3: layout = stack(.vertical, [media, row, cta])
      case .fullscreen4:
        let bottom = stack(.vertical, [row, cta])
        layout = stack(.vertical, [media, bottom])
        media.heightAnchor.constraint(equalTo: bottom.heightAnchor).isActive = true
      case .fullscreen5: layout = stack(.vertical, [cta, media, row])
      default: preconditionFailure("Unexpected fullscreen template")
      }
    } else if template.isSmall {
      layout = content(sideButton: true)
    } else if template == .medium1 || template == .medium2 {
      let media = media()
      let action = stack(.horizontal, [icon(32), cta])
      action.alignment = .center
      action.heightAnchor.constraint(equalToConstant: 44).isActive = true
      cta.heightAnchor.constraint(equalToConstant: 44).isActive = true
      let spacer = UIView()
      let copy = stack(.vertical, [details, spacer, action], spacing: 0)
      spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
      layout = stack(.horizontal, template == .medium1 ? [media, copy] : [copy, media])
      // 45% of the available width after the inter-column gap.
      media.widthAnchor.constraint(equalTo: layout.widthAnchor, multiplier: 0.45, constant: -3.6).isActive = true
    } else {
      let row = content(sideButton: template == .large5 || template == .large6, iconRight: template == .large4)
      if !template.isMedium { row.heightAnchor.constraint(equalToConstant: 64).isActive = true }
      if template != .large5 && template != .large6 { cta.heightAnchor.constraint(equalToConstant: 44).isActive = true }
      switch template {
      case .medium3, .medium5: layout = stack(.vertical, [row, cta])
      case .medium4, .medium6: layout = stack(.vertical, [cta, row])
      case .large1: layout = stack(.vertical, [row, media(), cta])
      case .large2, .large4: layout = stack(.vertical, [cta, row, media()])
      case .large3: layout = stack(.vertical, [row, cta, media()])
      case .large5: layout = stack(.vertical, [media(), row])
      case .large6: layout = stack(.vertical, [row, media()])
      default: preconditionFailure("Unexpected inline template")
      }
    }
    let panel = stack(.vertical, [attribution, layout], spacing: 0)
    pin(panel, to: view, inset: 8)
    view.nativeAd = ad
    return view
  }
}
