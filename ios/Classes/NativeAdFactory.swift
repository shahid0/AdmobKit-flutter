import Flutter
import GoogleMobileAds
import google_mobile_ads
import UIKit

public enum NativeAdLayoutKind {
  case big
  case medium
  case small
}

public final class NativeAdFactory: NSObject, FLTNativeAdFactory {
  public let layoutKind: NativeAdLayoutKind

  public init(layoutKind: NativeAdLayoutKind) {
    self.layoutKind = layoutKind
    super.init()
  }

  public func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let adView = NativeAdView()
    adView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
    adView.layer.cornerRadius = layoutKind == .small ? 12 : 10
    adView.layer.masksToBounds = true

    switch layoutKind {
    case .big:
      configureBigLayout(on: adView, nativeAd: nativeAd)
    case .medium:
      configureMediumLayout(on: adView, nativeAd: nativeAd)
    case .small:
      configureSmallLayout(on: adView, nativeAd: nativeAd)
    }

    adView.nativeAd = nativeAd
    return adView
  }

  private func configureBigLayout(on adView: NativeAdView, nativeAd: NativeAd) {
    let container = UIStackView()
    container.axis = .vertical
    container.spacing = 10
    container.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(container)

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
      container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12)
    ])

    let topRow = UIStackView()
    topRow.axis = .horizontal
    topRow.spacing = 8
    topRow.alignment = .center

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.layer.cornerRadius = 8
    iconView.layer.masksToBounds = true
    iconView.backgroundColor = .clear
    iconView.setContentCompressionResistancePriority(.required, for: .vertical)
    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 42),
      iconView.heightAnchor.constraint(equalToConstant: 42)
    ])

    let titleLabel = buildLabel(fontSize: 15, weight: .semibold)
    titleLabel.numberOfLines = 1
    let bodyLabel = buildLabel(fontSize: 13, weight: .regular)
    bodyLabel.textColor = UIColor(white: 0.9, alpha: 1)
    bodyLabel.numberOfLines = 2

    let titleStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
    titleStack.axis = .vertical
    titleStack.spacing = 2

    topRow.addArrangedSubview(iconView)
    topRow.addArrangedSubview(titleStack)

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.layer.cornerRadius = 8
    mediaView.layer.masksToBounds = true
    mediaView.backgroundColor = .clear
    mediaView.setContentHuggingPriority(.defaultLow, for: .vertical)
    mediaView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

    let mediaHeight = mediaView.heightAnchor.constraint(equalToConstant: 140)
    mediaHeight.priority = .defaultLow
    NSLayoutConstraint.activate([mediaHeight])

    let ctaButton = buildCTAButton(height: 38)
    ctaButton.setContentCompressionResistancePriority(.required, for: .vertical)
    NSLayoutConstraint.activate([
      ctaButton.heightAnchor.constraint(equalToConstant: 38)
    ])

    container.addArrangedSubview(topRow)
    container.addArrangedSubview(mediaView)
    container.addArrangedSubview(ctaButton)

    applyNativeAssets(
      adView: adView,
      nativeAd: nativeAd,
      headlineView: titleLabel,
      bodyView: bodyLabel,
      iconView: iconView,
      mediaView: mediaView,
      callToActionView: ctaButton
    )
  }

  private func configureMediumLayout(on adView: NativeAdView, nativeAd: NativeAd) {
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 10
    row.alignment = .fill
    row.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(row)

    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
      row.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
      row.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10)
    ])

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaView.layer.cornerRadius = 8
    mediaView.layer.masksToBounds = true
    mediaView.backgroundColor = .clear
    mediaView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let mediaWidth = mediaView.widthAnchor.constraint(equalToConstant: 96)
    mediaWidth.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([mediaWidth])

    let content = UIStackView()
    content.axis = .vertical
    content.spacing = 6
    content.distribution = .fill

    let titleLabel = buildLabel(fontSize: 14, weight: .semibold)
    titleLabel.numberOfLines = 1
    let bodyLabel = buildLabel(fontSize: 12, weight: .regular)
    bodyLabel.textColor = UIColor(white: 0.88, alpha: 1)
    bodyLabel.numberOfLines = 2
    bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

    let ctaButton = buildCTAButton(height: 32)
    ctaButton.setContentCompressionResistancePriority(.required, for: .vertical)
    NSLayoutConstraint.activate([
      ctaButton.heightAnchor.constraint(equalToConstant: 32)
    ])

    content.addArrangedSubview(titleLabel)
    content.addArrangedSubview(bodyLabel)

    let spacer = UIView()
    spacer.translatesAutoresizingMaskIntoConstraints = false
    spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
    content.addArrangedSubview(spacer)

    content.addArrangedSubview(ctaButton)

    row.addArrangedSubview(mediaView)
    row.addArrangedSubview(content)

    applyNativeAssets(
      adView: adView,
      nativeAd: nativeAd,
      headlineView: titleLabel,
      bodyView: bodyLabel,
      iconView: nil,
      mediaView: mediaView,
      callToActionView: ctaButton
    )
  }

  private func configureSmallLayout(on adView: NativeAdView, nativeAd: NativeAd) {
    let row = UIStackView()
    row.axis = .horizontal
    row.spacing = 8
    row.alignment = .center
    row.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(row)

    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
      row.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
      row.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
      row.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10)
    ])

    let iconView = UIImageView()
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.layer.cornerRadius = 8
    iconView.layer.masksToBounds = true
    iconView.backgroundColor = .clear
    iconView.setContentCompressionResistancePriority(.required, for: .vertical)
    iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
    NSLayoutConstraint.activate([
      iconView.widthAnchor.constraint(equalToConstant: 38),
      iconView.heightAnchor.constraint(equalToConstant: 38)
    ])

    let titleLabel = buildLabel(fontSize: 13, weight: .semibold)
    titleLabel.numberOfLines = 1
    let bodyLabel = buildLabel(fontSize: 11, weight: .regular)
    bodyLabel.textColor = UIColor(white: 0.85, alpha: 1)
    bodyLabel.numberOfLines = 1

    let textStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
    textStack.axis = .vertical
    textStack.spacing = 2
    textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let ctaButton = buildCTAButton(height: 30)
    ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    NSLayoutConstraint.activate([
      ctaButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 72),
      ctaButton.heightAnchor.constraint(equalToConstant: 30)
    ])

    row.addArrangedSubview(iconView)
    row.addArrangedSubview(textStack)
    row.addArrangedSubview(ctaButton)

    applyNativeAssets(
      adView: adView,
      nativeAd: nativeAd,
      headlineView: titleLabel,
      bodyView: bodyLabel,
      iconView: iconView,
      mediaView: nil,
      callToActionView: ctaButton
    )
  }

  private func applyNativeAssets(
    adView: NativeAdView,
    nativeAd: NativeAd,
    headlineView: UILabel,
    bodyView: UILabel?,
    iconView: UIImageView?,
    mediaView: MediaView?,
    callToActionView: UIButton
  ) {
    headlineView.text = nativeAd.headline
    adView.headlineView = headlineView

    if let body = nativeAd.body, let bodyView {
      bodyView.text = body
      bodyView.isHidden = false
      adView.bodyView = bodyView
    } else {
      bodyView?.isHidden = true
    }

    if let icon = nativeAd.icon?.image, let iconView {
      iconView.image = icon
      iconView.isHidden = false
      adView.iconView = iconView
    } else {
      iconView?.isHidden = true
    }

    if let mediaView {
      mediaView.mediaContent = nativeAd.mediaContent
      adView.mediaView = mediaView
    }

    callToActionView.setTitle(nativeAd.callToAction ?? "Install", for: .normal)
    callToActionView.isUserInteractionEnabled = false
    adView.callToActionView = callToActionView
  }

  private func buildLabel(fontSize: CGFloat, weight: UIFont.Weight) -> UILabel {
    let label = UILabel()
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = .systemFont(ofSize: fontSize, weight: weight)
    label.textColor = .white
    return label
  }

  private func buildCTAButton(height: CGFloat) -> UIButton {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.backgroundColor = UIColor(red: 0.57, green: 0.52, blue: 0.91, alpha: 1)
    button.layer.cornerRadius = height / 2.0
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
    return button
  }
}
