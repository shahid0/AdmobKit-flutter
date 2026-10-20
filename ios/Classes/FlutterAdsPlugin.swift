import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

public class FlutterAdsPlugin: NSObject, FlutterPlugin {
  private let appearance = NativeAppearanceStore()
  private var factories: [String: FLTNativeAdFactory] = [:]
  private weak var registrar: FlutterPluginRegistrar?
  private weak var engine: FlutterEngine?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_ads", binaryMessenger: registrar.messenger())
    let instance = FlutterAdsPlugin()
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.publish(instance)
    NativeAppearanceHostSetup.setUp(binaryMessenger: registrar.messenger(), api: instance.appearance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "registerNativeAdFactories":
      // Resolve this registrar's engine, never the process-wide AppDelegate.
      guard let engine = (registrar?.viewController as? FlutterViewController)?.engine else {
        result(FlutterError(code: "no-view-controller", message: "Native factories require this engine's FlutterViewController.", details: nil))
        return
      }
      self.engine = engine
      result(registerNativeAdFactories(registry: engine))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func registerNativeAdFactories(registry: FlutterPluginRegistry) -> Bool {
    unregisterNativeAdFactories(registry: registry)
    factories = Dictionary(uniqueKeysWithValues: NativeTemplate.allCases.map {
      ($0.factoryId, NativeAdFactory(template: $0, appearance: appearance) as FLTNativeAdFactory)
    })
    var registered = true
    for (id, factory) in factories {
      if !FLTGoogleMobileAdsPlugin.registerNativeAdFactory(registry, factoryId: id, nativeAdFactory: factory) {
        registered = false
      }
    }
    if !registered { unregisterNativeAdFactories(registry: registry) }
    return registered
  }

  private func unregisterNativeAdFactories(registry: FlutterPluginRegistry) {
    for id in factories.keys { FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(registry, factoryId: id) }
    factories.removeAll()
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    NativeAppearanceHostSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    appearance.clear()
    if let engine = engine { unregisterNativeAdFactories(registry: engine) }
    self.engine = nil
    self.registrar = nil
  }
}
