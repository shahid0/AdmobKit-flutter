package com.example.flutter_ads

import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

object NativeAdViewBinder {

    fun bindSmall(adView: NativeAdView, nativeAd: NativeAd) {
        bindHeadline(adView, nativeAd, R.id.ad_headline)
        bindBody(
            adView = adView,
            nativeAd = nativeAd,
            viewId = R.id.ad_body,
            fallbackText = nativeAd.advertiser.orEmpty()
        )
        bindIcon(adView, nativeAd, R.id.ad_app_icon)
        bindCallToAction(
            adView = adView,
            nativeAd = nativeAd,
            viewId = R.id.ad_call_to_action,
            fallbackText = "OPEN",
            uppercase = true
        )
        bindAdChoices(adView, R.id.ad_choices_view)
        adView.setNativeAd(nativeAd)
        wireContainerClick(adView, R.id.ad_call_to_action)
    }

    fun bindMedium(adView: NativeAdView, nativeAd: NativeAd) {
        bindMediaWithFallback(
            adView = adView,
            nativeAd = nativeAd,
            mediaId = R.id.ad_media,
            fallbackIconId = R.id.ad_media_fallback
        )
        bindHeadline(adView, nativeAd, R.id.ad_headline)
        bindAdvertiser(adView, nativeAd, R.id.ad_advertiser)
        bindBody(adView, nativeAd, R.id.ad_body)
        bindCallToAction(
            adView = adView,
            nativeAd = nativeAd,
            viewId = R.id.ad_call_to_action,
            fallbackText = "Learn More"
        )
        bindAdChoices(adView, R.id.ad_choices_view)
        adView.setNativeAd(nativeAd)
        wireContainerClick(adView, R.id.ad_call_to_action)
    }

    fun bindBig(adView: NativeAdView, nativeAd: NativeAd) {
        bindIcon(adView, nativeAd, R.id.ad_app_icon)
        bindHeadline(adView, nativeAd, R.id.ad_headline)
        bindBody(
            adView = adView,
            nativeAd = nativeAd,
            viewId = R.id.ad_body,
            fallbackText = nativeAd.advertiser.orEmpty()
        )
        bindRating(adView, nativeAd, R.id.rating)
        bindMediaWithFallback(
            adView = adView,
            nativeAd = nativeAd,
            mediaId = R.id.ad_media,
            fallbackIconId = R.id.ad_media_fallback,
            registerFallbackAsIcon = false
        )
        bindCallToAction(
            adView = adView,
            nativeAd = nativeAd,
            viewId = R.id.ad_call_to_action,
            fallbackText = "Open"
        )
        bindAdChoices(adView, R.id.ad_choices_view)
        adView.setNativeAd(nativeAd)
        wireContainerClick(adView, R.id.ad_call_to_action)
    }

    private fun bindHeadline(adView: NativeAdView, nativeAd: NativeAd, viewId: Int) {
        val headlineView = adView.findViewById<TextView>(viewId) ?: return
        val headline = nativeAd.headline.orEmpty()
        headlineView.text = headline
        headlineView.visibility = if (headline.isBlank()) View.GONE else View.VISIBLE
        adView.headlineView = headlineView
    }

    private fun bindAdvertiser(adView: NativeAdView, nativeAd: NativeAd, viewId: Int) {
        val advertiserView = adView.findViewById<TextView>(viewId) ?: return
        val advertiser = nativeAd.advertiser.orEmpty()
        advertiserView.text = advertiser
        advertiserView.visibility = if (advertiser.isBlank()) View.GONE else View.VISIBLE
        adView.advertiserView = advertiserView
    }

    private fun bindRating(adView: NativeAdView, nativeAd: NativeAd, viewId: Int) {
        val ratingView = adView.findViewById<TextView>(viewId) ?: return
        val starRating = nativeAd.starRating
        val store = nativeAd.store.orEmpty()
        val price = nativeAd.price.orEmpty()

        val ratingText = when {
            starRating != null && starRating > 0.0 -> {
                val ratingFormatted = if (starRating % 1.0 == 0.0) {
                    "${starRating.toInt()}.0"
                } else {
                    String.format(java.util.Locale.US, "%.1f", starRating)
                }
                if (store.isNotBlank()) {
                    "$ratingFormatted ★ · $store"
                } else if (price.isNotBlank()) {
                    "$ratingFormatted ★ · $price"
                } else {
                    "$ratingFormatted ★"
                }
            }
            store.isNotBlank() -> store
            nativeAd.advertiser.isNullOrBlank().not() -> nativeAd.advertiser.orEmpty()
            else -> ""
        }

        ratingView.text = ratingText
        ratingView.visibility = if (ratingText.isBlank()) View.GONE else View.VISIBLE
    }

    private fun bindBody(
        adView: NativeAdView,
        nativeAd: NativeAd,
        viewId: Int,
        fallbackText: String = ""
    ) {
        val bodyView = adView.findViewById<TextView>(viewId) ?: return
        val body = nativeAd.body?.takeIf { it.isNotBlank() } ?: fallbackText
        bodyView.text = body
        bodyView.visibility = if (body.isBlank()) View.GONE else View.VISIBLE
        adView.bodyView = bodyView
    }

    private fun bindIcon(adView: NativeAdView, nativeAd: NativeAd, viewId: Int) {
        val iconView = adView.findViewById<ImageView>(viewId) ?: return
        val icon = nativeAd.icon
        if (icon == null) {
            iconView.setImageDrawable(null)
            iconView.visibility = View.GONE
        } else {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        }
        adView.iconView = iconView
    }

    private fun bindMediaWithFallback(
        adView: NativeAdView,
        nativeAd: NativeAd,
        mediaId: Int,
        fallbackIconId: Int,
        registerFallbackAsIcon: Boolean = true
    ) {
        val mediaView = adView.findViewById<MediaView>(mediaId) ?: return
        val fallbackView = adView.findViewById<ImageView>(fallbackIconId)
        val mediaContent = nativeAd.mediaContent
        val hasRenderableMedia =
            mediaContent?.hasVideoContent() == true || !nativeAd.images.isNullOrEmpty()

        mediaView.mediaContent = mediaContent
        try {
            mediaView.setImageScaleType(ImageView.ScaleType.FIT_XY)
        } catch (_: Throwable) {
        }
        scaleMediaViewToFullWidth(mediaView, mediaContent?.aspectRatio ?: 0f)
        mediaView.visibility = if (hasRenderableMedia) View.VISIBLE else View.GONE
        adView.mediaView = mediaView

        val icon = nativeAd.icon
        if (fallbackView != null) {
            if (hasRenderableMedia) {
                fallbackView.setImageDrawable(null)
                fallbackView.visibility = View.GONE
            } else if (icon != null) {
                fallbackView.setImageDrawable(icon.drawable)
                fallbackView.visibility = View.VISIBLE
            } else {
                fallbackView.setImageDrawable(null)
                fallbackView.visibility = View.GONE
            }
            if (registerFallbackAsIcon) {
                adView.iconView = fallbackView
            }
        }
    }

    private fun bindCallToAction(
        adView: NativeAdView,
        nativeAd: NativeAd,
        viewId: Int,
        fallbackText: String,
        uppercase: Boolean = false
    ) {
        val ctaView = adView.findViewById<TextView>(viewId) ?: return
        val cta = nativeAd.callToAction?.takeIf { it.isNotBlank() } ?: fallbackText
        ctaView.text = if (uppercase) cta.uppercase() else cta
        ctaView.visibility = if (cta.isBlank()) View.GONE else View.VISIBLE
        ctaView.isClickable = true
        ctaView.isFocusable = false
        adView.callToActionView = ctaView
    }

    private fun wireContainerClick(adView: NativeAdView, ctaViewId: Int) {
        val ctaView = adView.findViewById<TextView>(ctaViewId) ?: return
        val container = adView.getChildAt(0)
        container?.isClickable = true
        container?.isFocusable = false
        container?.setOnClickListener {
            ctaView.performClick()
        }
    }

    private fun bindAdChoices(adView: NativeAdView, viewId: Int) {
        val adChoicesView = adView.findViewById<AdChoicesView>(viewId) ?: return
        adChoicesView.visibility = View.VISIBLE
        adView.adChoicesView = adChoicesView
    }

    private fun scaleMediaViewToFullWidth(
        mediaView: MediaView,
        aspectRatio: Float
    ) {
        mediaView.post {
            val mediaWidth = mediaView.width
            val mediaHeight = mediaView.height

            if (mediaWidth <= 0 || mediaHeight <= 0) {
                return@post
            }

            fun applyScale(view: View) {
                when (view) {
                    is TextureView -> {
                        if (aspectRatio <= 0f) {
                            view.scaleX = 1f
                            view.scaleY = 1f
                            return
                        }

                        val videoWidth = mediaHeight * aspectRatio
                        val videoHeight = mediaHeight.toFloat()
                        val scaleX = mediaWidth.toFloat() / videoWidth
                        val scaleY = mediaHeight.toFloat() / videoHeight
                        val scale = maxOf(scaleX, scaleY)

                        view.scaleX = scale
                        view.scaleY = scale
                        view.pivotX = view.width / 2f
                        view.pivotY = view.height / 2f
                    }
                    is ImageView -> {
                        view.scaleType = ImageView.ScaleType.CENTER_CROP
                    }
                    is ViewGroup -> {
                        for (i in 0 until view.childCount) {
                            applyScale(view.getChildAt(i))
                        }
                    }
                }
            }

            applyScale(mediaView)
        }

        mediaView.setOnHierarchyChangeListener(
            object : ViewGroup.OnHierarchyChangeListener {
                override fun onChildViewAdded(parent: View?, child: View?) {
                    child?.let {
                        mediaView.post {
                            applyTextureScale(it, mediaView, aspectRatio)
                        }
                    }
                }

                override fun onChildViewRemoved(parent: View?, child: View?) {
                }
            }
        )
    }

    private fun applyTextureScale(
        view: View,
        mediaView: MediaView,
        aspectRatio: Float
    ) {
        if (view is TextureView) {
            val parentWidth = mediaView.width
            val parentHeight = mediaView.height

            if (parentWidth > 0 && parentHeight > 0 && aspectRatio > 0f) {
                val videoWidth = parentHeight * aspectRatio
                val videoHeight = parentHeight.toFloat()
                val scaleX = parentWidth.toFloat() / videoWidth
                val scaleY = parentHeight.toFloat() / videoHeight
                val scale = maxOf(scaleX, scaleY)

                view.scaleX = scale
                view.scaleY = scale
                view.pivotX = view.width / 2f
                view.pivotY = view.height / 2f
            }
        } else if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                applyTextureScale(view.getChildAt(i), mediaView, aspectRatio)
            }
        }
    }
}
