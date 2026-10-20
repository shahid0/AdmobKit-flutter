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
 * for the typed inline template catalog
 * with the active [FlutterEngine].
 */
class FlutterAdsPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private val appearance = NativeAppearanceStore()
    private var channel: MethodChannel? = null
    private var attachedEngine: FlutterEngine? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = flutterPluginBinding.binaryMessenger
        NativeAppearanceHost.setUp(messenger, appearance)
        channel = MethodChannel(messenger, "flutter_ads")
        channel?.setMethodCallHandler(this)

        val engine = flutterPluginBinding.flutterEngine
        val context = flutterPluginBinding.applicationContext
        attachedEngine = engine
        applicationContext = context

        // Registration is awaited by AdSession after all engine plugins attach.
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
        NativeAppearanceHost.setUp(binding.binaryMessenger, null)
        appearance.clear()
        channel?.setMethodCallHandler(null)
        channel = null
        attachedEngine?.let { engine ->
            unregisterNativeAdFactories(engine)
        }
        attachedEngine = null
        applicationContext = null
    }

    private fun registerNativeAdFactories(flutterEngine: FlutterEngine, context: Context): Boolean {
        if (!flutterEngine.plugins.has(GoogleMobileAdsPlugin::class.java)) return false
        unregisterNativeAdFactories(flutterEngine)
        var registered = true
        for (template in NativeTemplate.entries) {
            val added = GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine, template.factoryId, NativeTemplateFactory(context, template, appearance))
            registered = added && registered
        }
        if (!registered) unregisterNativeAdFactories(flutterEngine)
        return registered
    }

    private fun unregisterNativeAdFactories(flutterEngine: FlutterEngine) {
        for (template in NativeTemplate.entries) {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, template.factoryId)
        }
    }
}
