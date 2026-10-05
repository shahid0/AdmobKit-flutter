// SDK assets and clicks remain SDK-owned. See THIRD_PARTY_NOTICES.md.
import GoogleMobileAds
import UIKit

enum NativeTemplateStyle {
  static let headline = UIColor(white: 15 / 255, alpha: 1)
  static let secondary = UIColor(white: 96 / 255, alpha: 1)
  static let inset: CGFloat = 8
  static let gap: CGFloat = 8
}

/// The bridge configures the real SDK view before Flutter mounts it.
final class NativeTemplateView: NativeAdView {
  var configure: ((NativeLayoutRequest) throws -> Double)?
  var separators: [UILabel] = []
}

final class NativeTemplateLayout {
  private let template: NativeTemplate
  init(template: NativeTemplate) { self.template = template }

  private func detach(_ view: UIView) {
    (view.superview as? UIStackView)?.removeArrangedSubview(view)
    view.removeFromSuperview()
  }

  private func stack(_ axis: NSLayoutConstraint.Axis, _ views: [UIView], spacing: CGFloat = 8) -> UIStackView {
    views.forEach(detach)
    let result = UIStackView(arrangedSubviews: views)
    result.axis = axis; result.spacing = spacing
    result.translatesAutoresizingMaskIntoConstraints = false
    return result
  }

  private func label(_ value: String?, size: CGFloat, primary: Bool = false) -> UILabel {
    let result = UILabel()
    result.text = value
    result.font = .systemFont(ofSize: size, weight: primary ? .semibold : .regular)
    result.textColor = primary ? NativeTemplateStyle.headline : NativeTemplateStyle.secondary
    result.numberOfLines = 0
    result.lineBreakMode = .byWordWrapping
    result.translatesAutoresizingMaskIntoConstraints = false
    result.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return result
  }

  private func pin(_ child: UIView, to parent: UIView, inset: CGFloat = 0, rightInset: CGFloat? = nil) {
    child.translatesAutoresizingMaskIntoConstraints = false
    parent.addSubview(child)
    NSLayoutConstraint.activate([
      child.leftAnchor.constraint(equalTo: parent.leftAnchor, constant: inset),
      child.rightAnchor.constraint(equalTo: parent.rightAnchor, constant: -(rightInset ?? inset)),
      child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
      child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
    ])
  }

  private func height(_ view: UIView, width: CGFloat) -> CGFloat {
    ceil(view.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height)
  }

  func build(_ ad: NativeAd) -> NativeTemplateView {
    let view = NativeTemplateView()
    view.backgroundColor = .white
    view.layer.cornerRadius = 12
    let panel = UIView()
    pin(panel, to: view, inset: 8)
    let badge = label("Ad", size: 11, primary: true)
    badge.accessibilityLabel = "Advertisement"
    badge.backgroundColor = .white
    badge.textAlignment = .center
    badge.layer.cornerRadius = 3
    badge.layer.borderWidth = 1
    badge.layer.borderColor = UIColor(white: 184 / 255, alpha: 1).cgColor
    let badgeWidth = badge.widthAnchor.constraint(equalToConstant: 26)
    let badgeHeight = badge.heightAnchor.constraint(equalToConstant: 20)
    NSLayoutConstraint.activate([badgeWidth, badgeHeight])

    let headline = label(ad.headline, size: 17, primary: true)
    let body = label(ad.body, size: 14)
    body.numberOfLines = 1
    body.lineBreakMode = .byClipping
    body.isHidden = ad.body?.isEmpty != false
    view.headlineView = headline; view.bodyView = body
    let button = UIButton(type: .custom)
    button.setTitle(ad.callToAction, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
    button.titleLabel?.numberOfLines = 0
    button.titleLabel?.lineBreakMode = .byWordWrapping
    button.titleLabel?.textAlignment = .center
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = NativeTemplateStyle.headline
    button.layer.cornerRadius = 8
    button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
    button.isHidden = ad.callToAction?.isEmpty != false
    button.isUserInteractionEnabled = false
    button.translatesAutoresizingMaskIntoConstraints = false
    view.callToActionView = button
    let buttonHeight = button.heightAnchor.constraint(equalToConstant: template.isFullscreen ? 48 : 44)
    buttonHeight.isActive = true

    var icon: UIImageView?
    if let asset = ad.icon {
      let image = UIImageView(image: asset.image)
      image.contentMode = .scaleAspectFit; image.layer.cornerRadius = 10; image.clipsToBounds = true
      image.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        image.widthAnchor.constraint(equalToConstant: 64),
        image.heightAnchor.constraint(equalToConstant: 64)
      ])
      view.iconView = image; icon = image
    }
    var metadataLabels: [UILabel] = []
    if let value = ad.starRating {
      let rating = label("\(value) ★", size: 12)
      view.starRatingView = rating; metadataLabels.append(rating)
    }
    if let value = ad.price, !value.isEmpty {
      let price = label(value, size: 12)
      view.priceView = price; metadataLabels.append(price)
    }
    if metadataLabels.isEmpty, let value = ad.advertiser, !value.isEmpty {
      let advertiser = label(value, size: 12)
      view.advertiserView = advertiser; metadataLabels.append(advertiser)
    }
    let needsMedia = template.hasMedia || ad.mediaContent.hasVideoContent
    let media: MediaView? = needsMedia ? MediaView() : nil
    if let media = media {
      media.mediaContent = ad.mediaContent
      media.contentMode = .scaleAspectFit
      media.translatesAutoresizingMaskIntoConstraints = false
      view.mediaView = media
    }
    let mediaHeight = media?.heightAnchor.constraint(equalToConstant: 144)
    mediaHeight?.isActive = true
    var oldLayout: UIStackView?
    let template = self.template
    // Captured assets are children of the SDK view; the closure never retains its owner.
    view.configure = { [weak view, weak panel] request in
      guard let view = view, let panel = panel else {
        throw PigeonError(code: "released-render", message: "Native view was released", details: nil)
      }
      guard request.width.isFinite, request.width >= 320,
        [request.headlineSize, request.bodySize, request.metadataSize, request.actionSize].allSatisfy({ $0.isFinite && $0 > 0 }) else {
        throw PigeonError(code: "invalid-layout", message: "Invalid native width or typography", details: nil)
      }
      [headline, body, badge, button].forEach(self.detach)
      metadataLabels.forEach(self.detach)
      if let icon = icon { self.detach(icon) }
      if let media = media { self.detach(media) }
      oldLayout?.removeFromSuperview()
      let width = CGFloat(request.width) - 16
      headline.font = .systemFont(ofSize: CGFloat(request.headlineSize), weight: .semibold)
      body.font = .systemFont(ofSize: CGFloat(request.bodySize))
      button.titleLabel?.font = .systemFont(ofSize: CGFloat(request.actionSize), weight: .semibold)
      for label in metadataLabels { label.font = .systemFont(ofSize: CGFloat(request.metadataSize)) }
      badge.font = .systemFont(ofSize: max(11, CGFloat(request.metadataSize) - 1), weight: .semibold)
      func naturalWidth(_ label: UILabel) -> CGFloat {
        ceil((label.text ?? "").size(withAttributes: [.font: label.font!]).width)
      }
      badgeWidth.constant = max(26, naturalWidth(badge) + 8)
      badgeHeight.constant = max(20, ceil(badge.font.lineHeight))
      let cornerInset: CGFloat = template.mediaFirst || (template.actionFirst && !button.isHidden) ? 0 : 24
      let iconWidth: CGFloat = icon == nil ? 0 : 74
      // Body is optional: keep the complete asset on one line or omit it.
      // Never shorten protected copy or shrink its font to force it to fit.
      let bodyHasLineBreak = ad.body?.rangeOfCharacter(from: .newlines) != nil
      body.isHidden = ad.body?.isEmpty != false || bodyHasLineBreak ||
        naturalWidth(body) > width - cornerInset - iconWidth
      let separatorWidth = naturalWidth(self.label("·", size: CGFloat(request.metadataSize))) + 8
      let metadataWidth = badgeWidth.constant + metadataLabels.reduce(CGFloat(0)) { $0 + naturalWidth($1) + separatorWidth }
      let copyWidth = width - cornerInset - iconWidth
      headline.preferredMaxLayoutWidth = copyWidth
      body.preferredMaxLayoutWidth = copyWidth
      let verticalMetadata = metadataWidth > copyWidth
      var metadata: [UIView] = [badge]
      view.separators.removeAll()
      for label in metadataLabels {
        label.preferredMaxLayoutWidth = copyWidth
        if !verticalMetadata {
          let separator = self.label("·", size: CGFloat(request.metadataSize))
          view.separators.append(separator); metadata.append(separator)
        }
        metadata.append(label)
      }
      let metadataStack = self.stack(verticalMetadata ? .vertical : .horizontal, metadata, spacing: verticalMetadata ? 2 : 4)
      metadataStack.alignment = verticalMetadata ? .leading : .center
      let details = self.stack(.vertical, body.isHidden ? [headline, metadataStack] : [headline, body, metadataStack], spacing: 4)
      details.setContentHuggingPriority(.defaultLow, for: .horizontal)
      let actionTextWidth = width - (template.actionFirst ? 24 : 0) - 24
      buttonHeight.constant = max(template.isFullscreen ? 48 : 44,
        ceil(button.titleLabel!.sizeThatFits(CGSize(width: actionTextWidth, height: .greatestFiniteMagnitude)).height) + 20)
      let action = UIView()
      action.translatesAutoresizingMaskIntoConstraints = false
      self.pin(button, to: action, rightInset: template.actionFirst ? 24 : 0)
      var rowAssets: [UIView] = [details]
      if let icon = icon {
        if template.trailingIcon { rowAssets.append(icon) } else { rowAssets.insert(icon, at: 0) }
      }
      let row = self.stack(.horizontal, rowAssets, spacing: 10)
      row.alignment = .center
      row.isLayoutMarginsRelativeArrangement = true
      row.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: cornerInset)
      var copyAssets: [UIView] = [row]
      if !button.isHidden {
        if template.actionFirst {
          copyAssets.insert(action, at: 0)
        } else { copyAssets.append(action) }
      }
      let copy = self.stack(.vertical, copyAssets)
      let footerHeight = self.height(copy, width: width)
      let layout: UIStackView
      if let media = media {
        mediaHeight?.constant = max(144, ceil(width * 9 / 16))
        if template.isFullscreen, let hostHeight = request.height {
          let available = CGFloat(hostHeight) - 16 - footerHeight - 8
          guard hostHeight.isFinite, available >= 144 else {
            throw PigeonError(code: "insufficient-height", message: "Fullscreen native assets need more height at this width/font size", details: nil)
          }
          mediaHeight?.constant = available
        }
        var assets: [UIView]
        if template.actionFirst {
          assets = button.isHidden ? [row, media] : [action, row, media]
        } else if template.mediaFirst {
          assets = button.isHidden ? [media, row] : [media, row, action]
        } else if template.actionMiddle {
          assets = button.isHidden ? [row, media] : [row, action, media]
        } else {
          assets = button.isHidden ? [row, media] : [row, media, action]
        }
        layout = self.stack(.vertical, assets)
      } else { layout = copy }
      let measured = self.height(layout, width: width) + 16
      self.pin(layout, to: panel)
      oldLayout = layout
      view.bounds = CGRect(x: 0, y: 0, width: CGFloat(request.width), height: measured)
      view.setNeedsLayout()
      view.layoutIfNeeded()
      return Double(measured)
    }
    _ = try? view.configure?(NativeLayoutRequest(width: 320, headlineSize: 17, bodySize: 14, metadataSize: 12, actionSize: 14))
    view.nativeAd = ad
    return view
  }
}
