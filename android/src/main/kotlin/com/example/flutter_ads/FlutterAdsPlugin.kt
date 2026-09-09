package com.example.flutter_ads

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * FlutterAdsPlugin
 *
 * Automatically registers and unregisters custom Native Ad factories
 * (`bigNativeAd`, `listTileMedium`, `listTile`, `listTiles`, `smallNativeAd`)
 * with the active [FlutterEngine].
 */
class FlutterAdsPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private var channel: MethodChannel? = null
    private var attachedEngine: FlutterEngine? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(messenger, "flutter_ads")
        channel?.setMethodCallHandler(this)

        val engine = flutterPluginBinding.flutterEngine
        val context = flutterPluginBinding.applicationContext
        attachedEngine = engine
        applicationContext = context

        registerNativeAdFactories(engine, context)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "registerNativeAdFactories" -> {
                val engine = attachedEngine
                val context = applicationContext
                if (engine != null && context != null) {
                    val registered = registerNativeAdFactories(engine, context)
                    result.success(registered)
                } else {
                    result.success(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        attachedEngine?.let { engine ->
            unregisterNativeAdFactories(engine)
        }
        attachedEngine = null
        applicationContext = null
    }

    companion object {
        const val BIG_NATIVE_FACTORY_ID = "bigNativeAd"
        const val MEDIUM_NATIVE_FACTORY_ID = "listTileMedium"
        const val LIST_TILE_FACTORY_ID = "listTile"
        const val LIST_TILES_FACTORY_ID = "listTiles"
        const val SMALL_NATIVE_FACTORY_ID = "smallNativeAd"

        fun registerNativeAdFactories(flutterEngine: FlutterEngine, context: Context): Boolean {
            return try {
                unregisterNativeAdFactories(flutterEngine)
                val bigFactory = BigNativeAdFactory(context)
                val mediumFactory = MediumNativeAdFactory(context)
                val smallFactory = SmallNativeAdFactory(context)

                GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    BIG_NATIVE_FACTORY_ID,
                    bigFactory
                )
                GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    MEDIUM_NATIVE_FACTORY_ID,
                    mediumFactory
                )
                GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    LIST_TILE_FACTORY_ID,
                    mediumFactory
                )
                GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    LIST_TILES_FACTORY_ID,
                    mediumFactory
                )
                GoogleMobileAdsPlugin.registerNativeAdFactory(
                    flutterEngine,
                    SMALL_NATIVE_FACTORY_ID,
                    smallFactory
                )
                true
            } catch (ignored: Throwable) {
                // If GoogleMobileAdsPlugin is not yet attached to engine in test harness
                false
            }
        }

        fun unregisterNativeAdFactories(flutterEngine: FlutterEngine) {
            try {
                GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, BIG_NATIVE_FACTORY_ID)
                GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, MEDIUM_NATIVE_FACTORY_ID)
                GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, LIST_TILE_FACTORY_ID)
                GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, LIST_TILES_FACTORY_ID)
                GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, SMALL_NATIVE_FACTORY_ID)
            } catch (ignored: Throwable) {
            }
        }
    }
}
