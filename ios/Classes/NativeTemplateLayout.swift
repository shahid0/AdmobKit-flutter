// SDK assets and clicks remain SDK-owned. See THIRD_PARTY_NOTICES.md.
import GoogleMobileAds
import UIKit

private enum NativeTemplateStyle {
  static let headline = UIColor(white: 15 / 255, alpha: 1)
  static let secondary = UIColor(white: 96 / 255, alpha: 1)
  static let action = UIColor(red: 6 / 255, green: 95 / 255, blue: 212 / 255, alpha: 1)
  static let actionBackground = UIColor(red: 222 / 255, green: 241 / 255, blue: 1, alpha: 1)
  static let inset: CGFloat = 8
  static let gap: CGFloat = 8
}

/// Shared editorial typography, attribution and asset binding across the catalog.
final class NativeTemplateLayout {
  private let template: NativeTemplate
  init(template: NativeTemplate) { self.template = template }

  private func stack(_ axis: NSLayoutConstraint.Axis, _ views: [UIView], spacing: CGFloat = NativeTemplateStyle.gap) -> UIStackView {
    let result = UIStackView(arrangedSubviews: views)
    result.axis = axis
    result.spacing = spacing
    result.translatesAutoresizingMaskIntoConstraints = false
    return result
  }

  private func label(_ value: String?, size: CGFloat, lines: Int = 1, primary: Bool = false) -> UILabel {
    let label = UILabel()
    label.text = value
    label.font = .systemFont(ofSize: size, weight: primary ? .semibold : .regular)
    label.textColor = primary ? NativeTemplateStyle.headline : NativeTemplateStyle.secondary
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
    view.layer.cornerRadius = 16

    let mediaFirst = [NativeTemplate.splitMediaLeft, .feedMediaFirst, .feedMediaTopSideCta, .fullscreenMediaFirst, .fullscreenTrailingIcon, .fullscreenMediaSideCta].contains(template)
    let actionFirst = [NativeTemplate.cardActionTop, .cardCleanActionTop].contains(template)
    let compactAction = template.isSmall || actionFirst || [NativeTemplate.splitMediaLeft, .splitMediaRight, .feedMediaTopSideCta, .feedContentTopSideCta, .fullscreenMediaSideCta].contains(template)

    let badge = label("Ad", size: 11, primary: true)
    badge.accessibilityLabel = "Advertisement"
    badge.backgroundColor = .white
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.layer.borderWidth = 1
    badge.layer.borderColor = UIColor(white: 184 / 255, alpha: 1).cgColor
    var metadataAssets: [UIView] = []
    if let value = ad.advertiser, !value.isEmpty {
      let advertiser = label(value, size: 12)
      view.advertiserView = advertiser
      metadataAssets.append(advertiser)
    }
    if template.hasMetadata {
      if let value = ad.starRating {
        let rating = label("\(value) ★", size: 12)
        rating.widthAnchor.constraint(equalToConstant: 44).isActive = true
        view.starRatingView = rating
        metadataAssets.append(rating)
      }
      if let value = ad.price, !value.isEmpty {
        let price = label(value, size: 12)
        price.widthAnchor.constraint(equalToConstant: 44).isActive = true
        view.priceView = price
        metadataAssets.append(price)
      }
    }
    // The SDK owns the top-right AdChoices overlay; no custom row or view.
    NSLayoutConstraint.activate([
      badge.widthAnchor.constraint(equalToConstant: 26),
      badge.heightAnchor.constraint(equalToConstant: 20)
    ])

    let headlineSize: CGFloat = template.isSmall ? 14 : template.isMedium ? 15 : 17
    let headline = label(ad.headline, size: headlineSize, lines: template.headlineLines, primary: true)
    let body = label(ad.body, size: template.isSmall ? 12 : template.isMedium ? 13 : 14, lines: template.bodyLines)
    body.isHidden = ad.body?.isEmpty != false
    view.headlineView = headline
    view.bodyView = body
    let title = stack(.horizontal, !mediaFirst && !actionFirst ? [badge, headline] : [headline], spacing: 6)
    title.alignment = .top
    var copyAssets: [UIView] = [title, body]
    if !metadataAssets.isEmpty {
      let metadata = stack(.horizontal, metadataAssets, spacing: 8)
      metadata.alignment = .center
      copyAssets.append(metadata)
    }
    let details = stack(.vertical, copyAssets, spacing: 4)
    details.setContentHuggingPriority(.required, for: .vertical)

    let button = UIButton(type: .custom)
    button.setTitle(ad.callToAction, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: template.isSmall ? 12 : 14, weight: .semibold)
    button.titleLabel?.numberOfLines = 2
    button.titleLabel?.textAlignment = .center
    button.titleLabel?.lineBreakMode = .byTruncatingTail
    button.setTitleColor(NativeTemplateStyle.action, for: .normal)
    button.backgroundColor = NativeTemplateStyle.actionBackground
    button.layer.cornerRadius = compactAction ? 20 : template.isFullscreen ? 24 : 22
    button.isHidden = ad.callToAction?.isEmpty != false
    // Google Mobile Ads handles clicks; no application gesture/target is installed.
    button.isUserInteractionEnabled = false
    view.callToActionView = button
    let cta = UIView()
    pin(button, to: cta)
    cta.isHidden = button.isHidden

    func icon(_ size: CGFloat) -> UIImageView? {
      guard template.hasIcon, let asset = ad.icon else { return nil }
      let image = UIImageView(image: asset.image)
      image.contentMode = .scaleAspectFit
      image.layer.cornerRadius = 10
      image.clipsToBounds = true
      image.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        image.widthAnchor.constraint(equalToConstant: size),
        image.heightAnchor.constraint(equalToConstant: size)
      ])
      view.iconView = image
      return image
    }
    func content(sideButton: Bool = false, iconRight: Bool = false, buttonLeading: Bool = false) -> UIStackView {
      var children: [UIView] = [details]
      if let icon = icon(template.isSmall ? 36 : 40) {
        if iconRight { children.append(icon) } else { children.insert(icon, at: 0) }
      }
      if sideButton && !cta.isHidden {
        if buttonLeading { children.insert(cta, at: 0) } else { children.append(cta) }
        cta.widthAnchor.constraint(equalToConstant: 88).isActive = true
        cta.heightAnchor.constraint(equalToConstant: 40).isActive = true
      }
      let row = stack(.horizontal, children, spacing: 8)
      row.alignment = template.isSmall || template.isMedium ? .center : .top
      if !mediaFirst && !actionFirst && template != .splitMediaRight {
        row.isLayoutMarginsRelativeArrangement = true
        // AdChoices is top-right, not semantic trailing, including in RTL.
        row.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 24)
      }
      row.setContentHuggingPriority(.required, for: .vertical)
      return row
    }
    func media() -> UIView {
      let media = MediaView()
      media.mediaContent = ad.mediaContent
      media.contentMode = .scaleAspectFit
      view.mediaView = media
      let container = UIView()
      container.translatesAutoresizingMaskIntoConstraints = false
      pin(media, to: container)
      container.heightAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
      if mediaFirst {
        container.addSubview(badge)
        NSLayoutConstraint.activate([
          badge.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 4),
          badge.topAnchor.constraint(equalTo: container.topAnchor, constant: 4)
        ])
      }
      return container
    }

    let layout: UIStackView
    if template.isFullscreen {
      let row = content(sideButton: template == .fullscreenMediaSideCta, iconRight: template == .fullscreenTrailingIcon)
      let media = media()
      if !cta.isHidden && template != .fullscreenMediaSideCta { cta.heightAnchor.constraint(equalToConstant: 48).isActive = true }
      switch template {
      case .fullscreenMediaFirst, .fullscreenTrailingIcon: layout = stack(.vertical, [media, row, cta])
      case .fullscreenContentFirst: layout = stack(.vertical, [row, media, cta])
      case .fullscreenMediaSideCta:
        layout = stack(.vertical, [media, row])
      case .fullscreenActionMiddle: layout = stack(.vertical, [row, cta, media])
      default: preconditionFailure("Unexpected fullscreen template")
      }
    } else if template.isSmall {
      layout = content(sideButton: true, iconRight: template == .rowWithTrailingIcon,
                       buttonLeading: template == .rowLeadingCta || template == .rowLeadingCtaCompact)
    } else if template == .splitMediaLeft || template == .splitMediaRight {
      let media = media()
      details.isLayoutMarginsRelativeArrangement = true
      details.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 24)
      if !cta.isHidden { cta.heightAnchor.constraint(equalToConstant: 40).isActive = true }
      let copy = stack(.vertical, [details, cta], spacing: 8)
      layout = stack(.horizontal, template == .splitMediaLeft ? [media, copy] : [copy, media])
      layout.alignment = .top
      media.widthAnchor.constraint(equalToConstant: 120).isActive = true
      media.bottomAnchor.constraint(equalTo: layout.bottomAnchor).isActive = true
    } else {
      let side = template == .feedMediaTopSideCta || template == .feedContentTopSideCta
      let row = content(sideButton: side, iconRight: template == .feedTrailingIcon)
      if !side && !cta.isHidden { cta.heightAnchor.constraint(equalToConstant: 44).isActive = true }
      switch template {
      case .cardContentTop, .cardCleanContentTop: layout = stack(.vertical, [row, cta])
      case .cardActionTop, .cardCleanActionTop:
        let cornerSpace = UIView()
        cornerSpace.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let action = stack(.horizontal, [badge, cta, cornerSpace], spacing: 6)
        action.alignment = .center
        layout = stack(.vertical, [action, row])
      case .feedMediaFirst: layout = stack(.vertical, [media(), row, cta])
      case .feedContentFirst, .feedTrailingIcon: layout = stack(.vertical, [row, media(), cta])
      case .feedActionMiddle: layout = stack(.vertical, [row, cta, media()])
      case .feedMediaTopSideCta: layout = stack(.vertical, [media(), row])
      case .feedContentTopSideCta: layout = stack(.vertical, [row, media()])
      default: preconditionFailure("Unexpected inline template")
      }
    }
    // Compact compositions hug content; only the media fills remaining height.
    let panel = UIView()
    pin(panel, to: view, inset: NativeTemplateStyle.inset)
    layout.translatesAutoresizingMaskIntoConstraints = false
    panel.addSubview(layout)
    NSLayoutConstraint.activate([
      layout.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
      layout.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
      layout.topAnchor.constraint(equalTo: panel.topAnchor)
    ])
    if template.isMedium && template != .splitMediaLeft && template != .splitMediaRight {
      layout.bottomAnchor.constraint(lessThanOrEqualTo: panel.bottomAnchor).isActive = true
    } else {
      layout.bottomAnchor.constraint(equalTo: panel.bottomAnchor).isActive = true
    }
    view.nativeAd = ad
    return view
  }
}
