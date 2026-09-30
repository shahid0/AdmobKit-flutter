// SDK assets and clicks remain SDK-owned. See THIRD_PARTY_NOTICES.md.
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
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

internal object NativeTemplateStyle {
    const val headline = 0xff0f0f0f.toInt()
    const val secondary = 0xff606060.toInt()
    const val action = 0xff065fd4.toInt()
    const val inset = 8
    const val gap = 8
}

/** Shared editorial typography, attribution and asset binding across the catalog. */
internal class NativeTemplateLayout(private val context: Context, private val template: NativeTemplate) {
    private val adView = NativeAdView(context)
    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
    private fun shape(color: Int, radius: Int, border: Int? = null) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radius).toFloat()
        border?.let { setStroke(dp(1).coerceAtLeast(1), it) }
    }
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
        parent.addView(view, LinearLayout.LayoutParams(
            if (width < 0) width else dp(width), if (height < 0) height else dp(height), weight))
    }
    private fun gap(parent: LinearLayout, size: Int = NativeTemplateStyle.gap) {
        add(parent, View(context), if (parent.orientation == LinearLayout.HORIZONTAL) size else 0,
            if (parent.orientation == LinearLayout.VERTICAL) size else 0)
    }

    fun build(ad: NativeAd): NativeAdView {
        val panel = stack(true).apply {
            id = R.id.ad_card_container
            setPadding(dp(NativeTemplateStyle.inset), dp(NativeTemplateStyle.inset),
                dp(NativeTemplateStyle.inset), dp(NativeTemplateStyle.inset))
            background = shape(Color.WHITE, 16)
        }
        adView.addView(panel, ViewGroup.LayoutParams(-1, -1))

        // Attribution uses the first asset's existing height, never a separate strip.
        val mediaFirst = template in setOf(NativeTemplate.medium1, NativeTemplate.large1,
            NativeTemplate.large5, NativeTemplate.fullscreen1, NativeTemplate.fullscreen3, NativeTemplate.fullscreen4)
        val actionFirst = template in setOf(NativeTemplate.medium4, NativeTemplate.medium6)
        val compactAction = template.isSmall || actionFirst || template in setOf(NativeTemplate.medium1,
            NativeTemplate.medium2, NativeTemplate.large5, NativeTemplate.large6, NativeTemplate.fullscreen4)
        val badge = text(11f, NativeTemplateStyle.headline).apply {
            id = R.id.ad_attribution_badge
            text = "Ad"
            contentDescription = "Advertisement"
            gravity = Gravity.CENTER
            background = shape(Color.WHITE, 3, 0xffb8b8b8.toInt())
            setTypeface(typeface, Typeface.BOLD)
        }
        val metadata = stack(false)
        if (!ad.advertiser.isNullOrEmpty()) {
            val advertiser = text(12f, NativeTemplateStyle.secondary).apply { text = ad.advertiser }
            adView.advertiserView = advertiser
            add(metadata, advertiser, 0, -2, 1f)
        }
        if (template.hasMetadata) {
            fun optional(value: String?, register: (TextView) -> Unit) {
                if (value.isNullOrEmpty()) return
                if (metadata.childCount > 0) gap(metadata, 8)
                val label = text(12f, NativeTemplateStyle.secondary).apply { text = value }
                register(label)
                add(metadata, label, 44)
            }
            optional(ad.starRating?.let { "$it ★" }) { adView.starRatingView = it }
            optional(ad.price) { adView.priceView = it }
        }
        // No custom AdChoicesView: the SDK inserts its own top-right overlay.

        val headlineSize = if (template.isSmall) 14f else if (template.isMedium) 15f else 17f
        val headline = text(headlineSize, NativeTemplateStyle.headline, template.headlineLines).apply {
            text = ad.headline
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        val body = text(if (template.isSmall) 12f else if (template.isMedium) 13f else 14f,
            NativeTemplateStyle.secondary, template.bodyLines).apply {
            text = ad.body
            visibility = if (ad.body.isNullOrEmpty()) View.GONE else View.VISIBLE
        }
        val cta = text(if (template.isSmall) 12f else 14f, NativeTemplateStyle.action, 2).apply {
            text = ad.callToAction
            gravity = Gravity.CENTER
            setTypeface(typeface, Typeface.BOLD)
            background = shape(0xffdef1ff.toInt(), if (compactAction) 20 else if (template.isFullscreen) 24 else 22)
            setPadding(dp(8), 0, dp(8), 0)
            visibility = if (ad.callToAction.isNullOrEmpty()) View.GONE else View.VISIBLE
        }
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta

        val details = stack(true)
        val title = stack(false).apply { gravity = Gravity.TOP }
        if (!mediaFirst && !actionFirst) { add(title, badge, 26, 20); gap(title, 6) }
        add(title, headline, 0, -2, 1f)
        add(details, title)
        if (!ad.body.isNullOrEmpty()) gap(details, 4)
        add(details, body)
        if (metadata.childCount > 0) { gap(details, 4); add(details, metadata) }

        fun icon(size: Int): ImageView? {
            if (ad.icon == null || !template.hasIcon) return null
            return ImageView(context).apply {
                scaleType = ImageView.ScaleType.FIT_CENTER
                setImageDrawable(ad.icon?.drawable)
                background = shape(Color.TRANSPARENT, 10)
                clipToOutline = true
                adView.iconView = this
            }
        }
        fun content(sideButton: Boolean = false, iconRight: Boolean = false, buttonLeading: Boolean = false): LinearLayout {
            val row = stack(false)
            if (!template.isSmall && !template.isMedium) row.gravity = Gravity.TOP
            val hasAction = sideButton && !ad.callToAction.isNullOrEmpty()
            if (hasAction && buttonLeading) { add(row, cta, 88, 40); gap(row, 8) }
            val size = if (template.isSmall) 36 else 40
            val icon = icon(size)
            if (icon != null && !iconRight) { add(row, icon, size, size); gap(row, 8) }
            add(row, details, 0, -2, 1f)
            if (icon != null && iconRight) { gap(row, 8); add(row, icon, size, size) }
            if (hasAction && !buttonLeading) { gap(row, 8); add(row, cta, 88, 40) }
            // Content-first cards leave the SDK's corner clear without a header row.
            if (!mediaFirst && !actionFirst && template != NativeTemplate.medium2) {
                row.setPadding(0, 0, dp(24), 0)
            }
            return row
        }
        fun media(): FrameLayout {
            val media = MediaView(context)
            adView.mediaView = media
            media.mediaContent = ad.mediaContent
            // Fit the supplied creative without cropping or covering SDK controls.
            media.setImageScaleType(ImageView.ScaleType.FIT_CENTER)
            return FrameLayout(context).apply {
                addView(media, FrameLayout.LayoutParams(-1, -1))
                if (mediaFirst) addView(badge, FrameLayout.LayoutParams(dp(26), dp(20), Gravity.TOP or Gravity.LEFT).apply {
                    topMargin = dp(4); leftMargin = dp(4)
                })
            }
        }

        val layout: LinearLayout
        if (template.isFullscreen) {
            layout = stack(true)
            val row = content(sideButton = template == NativeTemplate.fullscreen4,
                iconRight = template == NativeTemplate.fullscreen3)
            fun copy() { add(layout, row) }
            fun button() { add(layout, cta, height = if (ad.callToAction.isNullOrEmpty()) 0 else 48) }
            fun image() { add(layout, media(), height = 0, weight = 1f) }
            when (template) {
                NativeTemplate.fullscreen1, NativeTemplate.fullscreen3 -> { image(); gap(layout); copy(); gap(layout); button() }
                NativeTemplate.fullscreen2 -> { copy(); gap(layout); image(); gap(layout); button() }
                NativeTemplate.fullscreen4 -> { image(); gap(layout); copy() }
                NativeTemplate.fullscreen5 -> { copy(); gap(layout); button(); gap(layout); image() }
                else -> error("Unexpected fullscreen template: $template")
            }
        } else if (template.isSmall) {
            // Compact CTA is always a pill, never an oversized vertical rail.
            layout = content(sideButton = true, iconRight = template == NativeTemplate.small3,
                buttonLeading = template == NativeTemplate.small7 || template == NativeTemplate.small8)
        } else if (template == NativeTemplate.medium1 || template == NativeTemplate.medium2) {
            layout = stack(false)
            details.setPadding(0, 0, dp(24), 0)
            val copy = stack(true)
            add(copy, details)
            gap(copy, 8)
            add(copy, cta, height = if (ad.callToAction.isNullOrEmpty()) 0 else 40)
            if (template == NativeTemplate.medium1) {
                add(layout, media(), 120, -1); gap(layout); add(layout, copy, 0, -1, 1f)
            } else {
                add(layout, copy, 0, -1, 1f); gap(layout); add(layout, media(), 120, -1)
            }
        } else {
            layout = stack(true)
            val side = template == NativeTemplate.large5 || template == NativeTemplate.large6
            val row = content(sideButton = side, iconRight = template == NativeTemplate.large4)
            fun button() {
                if (actionFirst) {
                    val action = stack(false)
                    add(action, badge, 26, 20); gap(action, 6)
                    add(action, cta, 0, if (ad.callToAction.isNullOrEmpty()) 20 else 40, 1f)
                    gap(action, 24)
                    add(layout, action)
                } else add(layout, cta, height = if (ad.callToAction.isNullOrEmpty()) 0 else 44)
            }
            fun copy() { add(layout, row) }
            fun image() { add(layout, media(), height = 0, weight = 1f) }
            when (template) {
                NativeTemplate.medium3, NativeTemplate.medium5 -> { copy(); gap(layout); button() }
                NativeTemplate.medium4, NativeTemplate.medium6 -> { button(); gap(layout); copy() }
                NativeTemplate.large1 -> { image(); gap(layout); copy(); gap(layout); button() }
                NativeTemplate.large2, NativeTemplate.large4 -> { copy(); gap(layout); image(); gap(layout); button() }
                NativeTemplate.large3 -> { copy(); gap(layout); button(); gap(layout); image() }
                NativeTemplate.large5 -> { image(); gap(layout); copy() }
                NativeTemplate.large6 -> { copy(); gap(layout); image() }
                else -> error("Unexpected template: $template")
            }
        }
        // Top-align compact cards; flexible height belongs to media, not empty copy.
        layout.gravity = if (template.isSmall) Gravity.CENTER_VERTICAL else Gravity.TOP
        add(panel, layout, height = 0, weight = 1f)
        adView.setNativeAd(ad)
        return adView
    }
}
