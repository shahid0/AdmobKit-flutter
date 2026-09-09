import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

public class FlutterAdsPlugin: NSObject, FlutterPlugin {
  private static var nativeAdFactories: [String: FLTNativeAdFactory] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_ads", binaryMessenger: registrar.messenger())
    let instance = FlutterAdsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    if let registry = UIApplication.shared.delegate as? FlutterPluginRegistry {
      registerNativeAdFactories(registry: registry)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "registerNativeAdFactories":
      if let registry = UIApplication.shared.delegate as? FlutterPluginRegistry {
        let registered = FlutterAdsPlugin.registerNativeAdFactories(registry: registry)
        result(registered)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Registers the built-in Big, Medium, and Small native ad factories
  /// (`bigNativeAd`, `listTileMedium`, `listTile`, `listTiles`, `smallNativeAd`)
  /// with the host [FlutterPluginRegistry] (e.g. AppDelegate).
  @discardableResult
  public static func registerNativeAdFactories(registry: FlutterPluginRegistry) -> Bool {
    let bigFactory = NativeAdFactory(layoutKind: .big)
    let mediumFactory = NativeAdFactory(layoutKind: .medium)
    let smallFactory = NativeAdFactory(layoutKind: .small)

    nativeAdFactories = [
      "bigNativeAd": bigFactory,
      "listTile": mediumFactory,
      "listTileMedium": mediumFactory,
      "listTiles": mediumFactory,
      "smallNativeAd": smallFactory
    ]

    var allRegistered = true
    for (factoryId, factory) in nativeAdFactories {
      let registered = FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
        registry,
        factoryId: factoryId,
        nativeAdFactory: factory
      )
      if !registered {
        allRegistered = false
      }
    }
    return allRegistered
  }

  /// Unregisters all built-in native ad factories.
  public static func unregisterNativeAdFactories(registry: FlutterPluginRegistry) {
    for factoryId in nativeAdFactories.keys {
      FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(registry, factoryId: factoryId)
    }
    nativeAdFactories.removeAll()
  }
}
