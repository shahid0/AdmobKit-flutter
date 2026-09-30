// Arrangements adapted from flutter_monetization_kit, MIT (c) 2026 Hamza.
// See THIRD_PARTY_NOTICES.md. SDK assets and clicks remain SDK-owned.
package com.example.flutter_ads

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

/** One layout composition and asset-binding path for the entire inline catalog. */
internal class NativeTemplateLayout(private val context: Context, private val template: NativeTemplate) {
    private val adView = NativeAdView(context)
    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
    private fun shape(color: Int) = GradientDrawable().apply { setColor(color); cornerRadius = dp(8).toFloat() }
    private fun text(size: Float, color: Int, lines: Int = 1) = TextView(context).apply {
        textSize = size
        setTextColor(color)
        maxLines = lines
        ellipsize = TextUtils.TruncateAt.END
        includeFontPadding = false
        minimumWidth = 0
    }
    private fun stack(vertical: Boolean) = LinearLayout(context).apply {
        orientation = if (vertical) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }
    private fun add(parent: LinearLayout, view: View, width: Int = -1, height: Int = -2, weight: Float = 0f) {
        parent.addView(view, LinearLayout.LayoutParams(if (width < 0) width else dp(width), if (height < 0) height else dp(height), weight))
    }
    private fun gap(parent: LinearLayout) {
        add(parent, View(context), if (parent.orientation == LinearLayout.HORIZONTAL) 8 else 0,
            if (parent.orientation == LinearLayout.VERTICAL) 8 else 0)
    }

    fun build(ad: NativeAd): NativeAdView {
        val panel = stack(true).apply {
            id = R.id.ad_card_container
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = shape(Color.WHITE)
        }
        adView.addView(panel, ViewGroup.LayoutParams(-1, -1))

        val attribution = stack(false)
        val badge = text(10f, Color.BLACK).apply {
            text = "Ad"
            gravity = Gravity.CENTER
            background = shape(0xffffcc00.toInt())
            setTypeface(typeface, Typeface.BOLD)
        }
        add(attribution, badge, 24, 16)
        add(attribution, View(context), 0, 0, 1f)
        val choices = AdChoicesView(context).apply { minimumWidth = dp(24) }
        adView.adChoicesView = choices
        add(attribution, choices, -2, 24)
        add(panel, attribution, height = 24)

        val headline = text(if (template.isFullscreen) 17f else 14f, Color.BLACK, if (template.isFullscreen) 2 else 1).apply {
            text = ad.headline
            setTypeface(typeface, Typeface.BOLD)
        }
        val body = text(12f, Color.DKGRAY, template.bodyLines).apply {
            text = ad.body
            visibility = if (ad.body.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
        }
        val cta = text(12f, Color.WHITE).apply {
            text = ad.callToAction
            gravity = Gravity.CENTER
            background = shape(0xff2196f3.toInt())
            setPadding(dp(4), 0, dp(4), 0)
            visibility = if (ad.callToAction.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
        }
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta

        val details = stack(true)
        add(details, headline)
        add(details, body)
        if (template.hasMetadata) {
            val metadata = stack(false)
            val advertiser = text(10f, Color.DKGRAY).apply {
                text = ad.advertiser
                visibility = if (ad.advertiser.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
            }
            val rating = text(10f, Color.DKGRAY).apply {
                text = ad.starRating?.let { "$it ★" }
                visibility = if (ad.starRating == null) View.INVISIBLE else View.VISIBLE
            }
            val price = text(10f, Color.DKGRAY).apply {
                text = ad.price
                visibility = if (ad.price.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
            }
            adView.advertiserView = advertiser
            adView.starRatingView = rating
            adView.priceView = price
            add(metadata, advertiser, 0, -2, 1f)
            add(metadata, rating, -2)
            add(metadata, price, 0, -2, 1f)
            add(details, metadata, height = 16)
        }

        fun content(sideButton: Boolean = false, iconRight: Boolean = false): LinearLayout {
            val row = stack(false)
            val icon = if (template.hasIcon) ImageView(context).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                setImageDrawable(ad.icon?.drawable)
                visibility = if (ad.icon == null) View.INVISIBLE else View.VISIBLE
                adView.iconView = this
            } else null
            val iconSize = if (template.isFullscreen) 56 else 48
            if (icon != null && !iconRight) { add(row, icon, iconSize, iconSize); gap(row) }
            add(row, details, 0, -2, 1f)
            if (icon != null && iconRight) { gap(row); add(row, icon, 48, 48) }
            if (sideButton) { gap(row); add(row, cta, 84, if (template.tallButton) -1 else 40) }
            return row
        }
        fun media() = MediaView(context).also {
            adView.mediaView = it
            it.mediaContent = ad.mediaContent
            it.setImageScaleType(ImageView.ScaleType.FIT_CENTER)
        }
        val layout: LinearLayout
        if (template.isFullscreen) {
            layout = stack(true)
            val row = content()
            fun copy() { add(layout, row, height = 96) }
            fun button() { add(layout, cta, height = 52) }
            fun image() { add(layout, media(), height = 0, weight = 1f) }
            when (template) {
                NativeTemplate.fullscreen1 -> { copy(); gap(layout); image(); gap(layout); button() }
                NativeTemplate.fullscreen2 -> { button(); gap(layout); copy(); gap(layout); image() }
                // Keep video controls clear: content occupies its own bottom panel.
                NativeTemplate.fullscreen3 -> { image(); gap(layout); copy(); gap(layout); button() }
                NativeTemplate.fullscreen4 -> {
                    image(); gap(layout)
                    val bottom = stack(true)
                    add(bottom, row, height = 0, weight = 1f); gap(bottom)
                    add(bottom, cta, height = 52)
                    add(layout, bottom, height = 0, weight = 1f)
                }
                NativeTemplate.fullscreen5 -> { button(); gap(layout); image(); gap(layout); copy() }
                else -> error("Unexpected fullscreen template: $template")
            }
        } else if (template.isSmall) {
            layout = content(sideButton = true)
        } else if (template == NativeTemplate.medium1 || template == NativeTemplate.medium2) {
            layout = stack(false)
            val copy = stack(true)
            // A narrow half-card uses text above the icon/CTA to keep the headline legible.
            add(copy, details, height = 0, weight = 1f)
            val actionRow = stack(false)
            val icon = ImageView(context).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                setImageDrawable(ad.icon?.drawable)
                visibility = if (ad.icon == null) View.INVISIBLE else View.VISIBLE
                adView.iconView = this
            }
            add(actionRow, icon, 32, 32); gap(actionRow)
            add(actionRow, cta, 0, 44, 1f)
            add(copy, actionRow, height = 44)
            if (template == NativeTemplate.medium1) {
                add(layout, media(), 0, -1, 0.45f); gap(layout); add(layout, copy, 0, -1, 0.55f)
            } else {
                add(layout, copy, 0, -1, 0.55f); gap(layout); add(layout, media(), 0, -1, 0.45f)
            }
        } else {
            layout = stack(true)
            val row = content(sideButton = template == NativeTemplate.large5 || template == NativeTemplate.large6,
                iconRight = template == NativeTemplate.large4)
            fun button() { add(layout, cta, height = 44) }
            fun copy() { add(layout, row, height = if (template.isMedium) 0 else 64, weight = if (template.isMedium) 1f else 0f) }
            fun image() { add(layout, media(), height = 0, weight = 1f) }
            when (template) {
                NativeTemplate.medium3, NativeTemplate.medium5 -> { copy(); gap(layout); button() }
                NativeTemplate.medium4, NativeTemplate.medium6 -> { button(); gap(layout); copy() }
                NativeTemplate.large1 -> { copy(); gap(layout); image(); gap(layout); button() }
                NativeTemplate.large2, NativeTemplate.large4 -> { button(); gap(layout); copy(); gap(layout); image() }
                NativeTemplate.large3 -> { copy(); gap(layout); button(); gap(layout); image() }
                NativeTemplate.large5 -> { image(); gap(layout); copy() }
                NativeTemplate.large6 -> { copy(); gap(layout); image() }
                else -> error("Unexpected template: $template")
            }
        }
        add(panel, layout, height = 0, weight = 1f)
        adView.setNativeAd(ad)
        return adView
    }
}
