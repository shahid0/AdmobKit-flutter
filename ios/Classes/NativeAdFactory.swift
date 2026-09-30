import Flutter
import GoogleMobileAds
import google_mobile_ads

/// Factory boundary only; layout and live appearance have separate owners.
final class NativeAdFactory: NSObject, FLTNativeAdFactory {
  private let template: NativeTemplate
  private let appearance: NativeAppearanceStore

  init(template: NativeTemplate, appearance: NativeAppearanceStore) {
    self.template = template
    self.appearance = appearance
    super.init()
  }

  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable: Any]? = nil) -> NativeAdView? {
    let view = NativeTemplateLayout(template: template).build(nativeAd)
    appearance.attach(view, options: customOptions)
    return view
  }
}
