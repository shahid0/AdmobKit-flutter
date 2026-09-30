package com.example.flutter_ads

import android.content.res.ColorStateList
import android.graphics.drawable.Drawable
import android.view.View
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAdView
import java.lang.ref.WeakReference

/** Engine-owned, main-thread registry. A manifest reserves views before SDK load. */
internal class NativeAppearanceStore : NativeAppearanceHost {
    private var session: String? = null
    private var revision = -1L
    private var palettes = emptyMap<String, NativePalette>()
    private val views = mutableMapOf<String, StyledNativeView>()

    override fun startSession(sessionId: String) {
        clear()
        session = sessionId
    }

    override fun applyColors(sessionId: String, revision: Long, renders: Map<String, NativePalette>) {
        check(session == sessionId) { "Native appearance session is no longer active" }
        if (revision <= this.revision) return
        this.revision = revision
        palettes = renders.toMap()
        views.keys.retainAll(renders.keys)
        for ((id, view) in views) renders[id]?.let(view::apply)
    }

    override fun endSession(sessionId: String) {
        if (session == sessionId) clear()
    }

    fun clear() {
        session = null
        revision = -1L
        palettes = emptyMap()
        views.clear()
    }

    fun attach(view: NativeAdView, options: Map<String, Any>?) {
        if (session == null || options?.get("sessionId") != session) return
        val id = options?.get("renderId") as? String ?: return
        val palette = palettes[id] ?: return // released/cancelled before native creation
        val styled = StyledNativeView(view)
        views[id] = styled
        styled.apply(palette)
    }
}

/** Retain defaults, never the SDK view. Resets preserve template drawables/shape. */
private class StyledNativeView(view: NativeAdView) {
    private val view = WeakReference(view)
    private val background = BackgroundDefaults(view.findViewById<View>(R.id.ad_card_container) ?: view)
    private val headline = (view.headlineView as? TextView)?.textColors
    private val secondaryDefaults = secondaryText(view).map { it.textColors }
    private val cta = (view.callToActionView as? TextView)?.textColors
    private val ctaBackground = view.callToActionView?.let(::BackgroundDefaults)

    fun apply(colors: NativePalette) {
        val ad = view.get() ?: return
        background.apply(ad.findViewById<View>(R.id.ad_card_container) ?: ad, colors.background)
        (ad.headlineView as? TextView)?.setTextColor(colors.headline?.let { ColorStateList.valueOf(it.toInt()) } ?: headline)
        for ((text, original) in secondaryText(ad).zip(secondaryDefaults)) {
            text.setTextColor(colors.body?.let { ColorStateList.valueOf(it.toInt()) } ?: original)
        }
        (ad.callToActionView as? TextView)?.setTextColor(colors.callToActionText?.let { ColorStateList.valueOf(it.toInt()) } ?: cta)
        ad.callToActionView?.let { ctaBackground?.apply(it, colors.callToActionBackground) }
    }

    private fun secondaryText(ad: NativeAdView) =
        listOf(ad.bodyView, ad.advertiserView, ad.starRatingView, ad.priceView).filterIsInstance<TextView>()
}

private class BackgroundDefaults(view: View) {
    private val drawable: Drawable.ConstantState? = view.background?.constantState
    private val tint = view.backgroundTintList

    fun apply(view: View, color: Long?) {
        view.background = drawable?.newDrawable(view.resources)?.mutate()
        view.backgroundTintList = tint
        if (color != null) {
            if (view.background == null) view.setBackgroundColor(color.toInt())
            else view.backgroundTintList = ColorStateList.valueOf(color.toInt())
        }
    }
}
