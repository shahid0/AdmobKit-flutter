package com.example.flutter_ads_example
 
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.flutter_ads.FlutterAdsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterAdsPlugin.registerNativeAdFactories(flutterEngine, context)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterAdsPlugin.unregisterNativeAdFactories(flutterEngine)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
