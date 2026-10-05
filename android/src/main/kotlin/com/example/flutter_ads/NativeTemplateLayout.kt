// SDK assets and clicks remain SDK-owned. See THIRD_PARTY_NOTICES.md.
package com.example.flutter_ads

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import kotlin.math.ceil
import kotlin.math.max

internal object NativeTemplateStyle {
    const val headline = 0xff0f0f0f.toInt()
    const val secondary = 0xff606060.toInt()
    const val action = Color.WHITE
    const val inset = 8
    const val gap = 8
    const val icon = 64
    const val radius = 8
}

/** The bridge measures the SDK view before Flutter mounts it. No post-frame resize. */
internal class NativeTemplatePanel(context: Context) : LinearLayout(context) {
    lateinit var configure: (NativeLayoutRequest) -> Double
    val separators = mutableListOf<TextView>()
}

internal class NativeTemplateLayout(private val context: Context, private val template: NativeTemplate) {
    private val adView = NativeAdView(context)
    private fun dp(value: Double) = ceil(value * context.resources.displayMetrics.density).toInt()
    private fun dp(value: Int) = dp(value.toDouble())
    private fun shape(color: Int, radius: Int, border: Int? = null) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat()
        border?.let { setStroke(dp(1), it) }
    }
    private fun text(value: String?, size: Double, primary: Boolean = false) = TextView(context).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_DIP, size.toFloat())
        setTextColor(if (primary) NativeTemplateStyle.headline else NativeTemplateStyle.secondary)
        if (primary) typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        // Native wrapping preserves all copy, including the protected 25/90 characters.
        includeFontPadding = false
        minimumWidth = 0
    }
    private fun stack(vertical: Boolean) = LinearLayout(context).apply {
        orientation = if (vertical) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
    }
    private fun add(parent: LinearLayout, child: View, width: Int = -1, height: Int = -2, weight: Float = 0f) {
        (child.parent as? ViewGroup)?.removeView(child)
        parent.addView(child, LinearLayout.LayoutParams(
            if (width < 0) width else dp(width), if (height < 0) height else dp(height), weight))
    }
    private fun gap(parent: LinearLayout, size: Int = NativeTemplateStyle.gap) {
        add(parent, View(context), if (parent.orientation == LinearLayout.HORIZONTAL) size else 0,
            if (parent.orientation == LinearLayout.VERTICAL) size else 0)
    }
    private fun measuredHeight(view: View, width: Int): Int {
        view.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        return view.measuredHeight
    }
    private fun naturalWidth(view: TextView): Int {
        view.measure(View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED))
        return view.measuredWidth
    }

    fun build(ad: NativeAd): NativeAdView {
        val panel = NativeTemplatePanel(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP
            id = R.id.ad_card_container
            setPadding(dp(8), dp(8), dp(8), dp(8))
            background = shape(Color.WHITE, 12)
        }
        adView.addView(panel, ViewGroup.LayoutParams(-1, -1))
        val badge = text("Ad", 11.0, true).apply {
            id = R.id.ad_attribution_badge
            contentDescription = "Advertisement"
            gravity = Gravity.CENTER
            background = shape(Color.WHITE, 3, 0xffb8b8b8.toInt())
        }
        val headline = text(ad.headline, 17.0, true)
        val body = text(ad.body, 14.0).apply {
            maxLines = 1
            visibility = if (ad.body.isNullOrEmpty()) View.GONE else View.VISIBLE
        }
        val cta = text(ad.callToAction, 14.0, true).apply {
            setTextColor(NativeTemplateStyle.action)
            gravity = Gravity.CENTER
            background = shape(NativeTemplateStyle.headline, NativeTemplateStyle.radius)
            setPadding(dp(12), dp(10), dp(12), dp(10))
            minimumHeight = dp(if (template.isFullscreen) 48 else 44)
            visibility = if (ad.callToAction.isNullOrEmpty()) View.GONE else View.VISIBLE
        }
        adView.headlineView = headline; adView.bodyView = body; adView.callToActionView = cta
        val icon = ad.icon?.let { asset -> ImageView(context).apply {
            scaleType = ImageView.ScaleType.FIT_CENTER
            setImageDrawable(asset.drawable)
            background = shape(Color.TRANSPARENT, 10); clipToOutline = true
            adView.iconView = this
        } }
        val metadataLabels = mutableListOf<TextView>()
        ad.starRating?.let { value -> text("$value ★", 12.0).also {
            adView.starRatingView = it; metadataLabels.add(it)
        } }
        ad.price?.takeIf { it.isNotEmpty() }?.let { value -> text(value, 12.0).also {
            adView.priceView = it; metadataLabels.add(it)
        } }
        // App-store metadata and advertiser identity do not compete in the same row.
        if (metadataLabels.isEmpty()) ad.advertiser?.takeIf { it.isNotEmpty() }?.let { value ->
            text(value, 12.0).also { adView.advertiserView = it; metadataLabels.add(it) }
        }
        val needsMedia = template.hasMedia || ad.mediaContent?.hasVideoContent() == true
        val media = if (needsMedia) MediaView(context).apply {
            mediaContent = ad.mediaContent
            setImageScaleType(ImageView.ScaleType.FIT_CENTER)
            adView.mediaView = this
        } else null

        panel.configure = { request ->
            require(request.width.isFinite() && request.width >= 320)
            require(listOf(request.headlineSize, request.bodySize, request.metadataSize, request.actionSize).all { it.isFinite() && it > 0 })
            val width = dp(request.width) - dp(16)
            headline.setTextSize(TypedValue.COMPLEX_UNIT_DIP, request.headlineSize.toFloat())
            body.setTextSize(TypedValue.COMPLEX_UNIT_DIP, request.bodySize.toFloat())
            cta.setTextSize(TypedValue.COMPLEX_UNIT_DIP, request.actionSize.toFloat())
            for (label in metadataLabels) label.setTextSize(TypedValue.COMPLEX_UNIT_DIP, request.metadataSize.toFloat())
            badge.setTextSize(TypedValue.COMPLEX_UNIT_DIP, max(11.0, request.metadataSize - 1).toFloat())
            val badgeWidth = max(dp(26), naturalWidth(badge) + dp(8))
            val badgeHeight = max(dp(20), measuredHeight(badge, badgeWidth))
            val mediaWidth = if (template.isSplit) dp(120) else width
            val contentWidth = if (template.isSplit) width - mediaWidth - dp(8) else width
            val cornerInset = if (!(media != null && (template.mediaFirst || template == NativeTemplate.splitMediaRight)) &&
                !(template.actionFirst && cta.visibility == View.VISIBLE)) dp(24) else 0
            // Smart media has a two-line identity; its attribution sits below
            // that row, allowing a smaller icon without squeezing store metadata.
            val iconSize = if (template.isSplit) 40 else NativeTemplateStyle.icon
            val iconWidth = if (icon == null) 0 else dp(iconSize + 10)
            val identityWidth = contentWidth - cornerInset
            val side = template.sideAction && cta.visibility == View.VISIBLE
            // Keep the requested composition. Native text wraps in its assigned
            // width; it never causes a same-row action to migrate below identity.
            val actionWidth = if (side) max(dp(76), naturalWidth(cta)).coerceAtMost(identityWidth / 3) else 0
            val copyWidth = identityWidth - iconWidth - if (side) actionWidth + dp(8) else 0
            require(copyWidth > 0) { "Native identity needs more width" }
            // Body is optional. Omit it if the complete asset cannot fit one line;
            // clipping or ellipsizing here could violate the 90-character minimum.
            val bodyHasLineBreak = ad.body?.any { it in "\n\r\u0085\u2028\u2029\u000b\u000c" } == true
            body.visibility = if (!ad.body.isNullOrEmpty() && !bodyHasLineBreak &&
                naturalWidth(body) <= copyWidth) View.VISIBLE else View.GONE
            val separatorWidth = naturalWidth(text("·", request.metadataSize)) + dp(8)
            val metadataWidth = badgeWidth + metadataLabels.sumOf { naturalWidth(it) + separatorWidth }
            val details = stack(true)
            add(details, headline)
            if (body.visibility != View.GONE) { gap(details, 4); add(details, body) }
            if (!template.isSplit) gap(details, 4)
            val metadata = stack(false)
            val metadataAvailableWidth = if (template.isSplit) contentWidth else copyWidth
            val verticalMetadata = metadataWidth > metadataAvailableWidth
            panel.separators.clear()
            metadata.orientation = if (verticalMetadata) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            add(metadata, badge, -2, -2)
            badge.layoutParams.width = badgeWidth; badge.layoutParams.height = badgeHeight
            for (label in metadataLabels) {
                gap(metadata, if (verticalMetadata) 2 else 4)
                if (!verticalMetadata) {
                    val separator = text("·", request.metadataSize)
                    panel.separators.add(separator)
                    add(metadata, separator, -2); gap(metadata, 4)
                }
                add(metadata, label, if (verticalMetadata) -1 else -2)
            }
            if (!template.isSplit) add(details, metadata)
            val row = stack(false)
            fun rowAction() {
                add(row, cta, 0)
                cta.layoutParams.width = actionWidth
            }
            if (side && template.leadingAction) { rowAction(); gap(row) }
            if (icon != null && !template.trailingIcon) { add(row, icon, iconSize, iconSize); gap(row, 10) }
            add(row, details, 0, -2, 1f)
            if (icon != null && template.trailingIcon) { gap(row, 10); add(row, icon, iconSize, iconSize) }
            if (side && !template.leadingAction) { gap(row); rowAction() }
            row.setPadding(0, 0, cornerInset, 0)
            val copy = stack(true)
            fun copyAction() {
                add(copy, cta)
                if (template.actionFirst) (cta.layoutParams as LinearLayout.LayoutParams).rightMargin = dp(24)
            }
            if (template.actionFirst && !side && cta.visibility == View.VISIBLE) { copyAction(); gap(copy) }
            add(copy, row)
            if (template.isSplit) { gap(copy, 4); add(copy, metadata) }
            if (!template.actionFirst && !side && cta.visibility == View.VISIBLE) { gap(copy); copyAction() }
            val layout = stack(!template.isSplit)
            val footerHeight = measuredHeight(copy, contentWidth)
            var mediaHeight = if (media == null) 0 else if (template.isSplit) dp(120)
                else max(dp(144), ceil(width * 9.0 / 16).toInt())
            if (template.isFullscreen && request.height != null) {
                val hostHeight = request.height!!
                require(hostHeight.isFinite() && hostHeight > 0)
                val available = dp(hostHeight) - dp(16) - footerHeight - dp(8)
                require(available >= dp(144)) { "Fullscreen native assets need more height at this width/font size" }
                mediaHeight = available
            }
            fun image() { if (media != null) { add(layout, media, height = 0); media.layoutParams.height = mediaHeight } }
            fun action() {
                if (!side && cta.visibility == View.VISIBLE) {
                    add(layout, cta)
                    if (template.actionFirst) (cta.layoutParams as LinearLayout.LayoutParams).rightMargin = dp(24)
                }
            }
            if (media == null) add(layout, copy)
            else when {
                template.isSplit -> {
                    fun splitImage() {
                        add(layout, media, 0, 0)
                        media.layoutParams.width = mediaWidth
                        media.layoutParams.height = mediaHeight
                    }
                    if (template == NativeTemplate.splitMediaLeft) { splitImage(); gap(layout) }
                    add(layout, copy, 0, -2, 1f)
                    if (template == NativeTemplate.splitMediaRight) { gap(layout); splitImage() }
                }
                template.actionFirst -> {
                    if (cta.visibility == View.VISIBLE) { action(); gap(layout) }
                    add(layout, row); gap(layout); image()
                }
                template.mediaFirst -> {
                    image(); gap(layout); add(layout, row)
                    if (!side && cta.visibility == View.VISIBLE) { gap(layout); action() }
                }
                template.actionMiddle -> {
                    add(layout, row)
                    if (!side && cta.visibility == View.VISIBLE) { gap(layout); action() }
                    gap(layout); image()
                }
                else -> {
                    add(layout, row); gap(layout); image()
                    if (!side && cta.visibility == View.VISIBLE) { gap(layout); action() }
                }
            }
            val naturalHeight = if (media == null) footerHeight else if (template.isSplit) max(mediaHeight, footerHeight)
                else mediaHeight + dp(8) + footerHeight
            panel.removeAllViews()
            add(panel, layout)
            (naturalHeight + dp(16)).toDouble() / context.resources.displayMetrics.density
        }
        panel.configure(NativeLayoutRequest(width = 320.0, headlineSize = 17.0, bodySize = 14.0, metadataSize = 12.0, actionSize = 14.0))
        adView.setNativeAd(ad)
        return adView
    }
}
