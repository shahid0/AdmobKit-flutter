package com.example.flutter_ads

import android.content.Context
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/** SDK factory only: loading, ownership and live colors belong to the engine. */
internal class NativeTemplateFactory(
    private val context: Context,
    private val template: NativeTemplate,
    private val appearance: NativeAppearanceStore
) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        val view = NativeTemplateLayout(context, template).build(nativeAd)
        appearance.attach(view, customOptions)
        return view
    }
}
