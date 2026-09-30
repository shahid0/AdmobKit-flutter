package com.example.flutter_ads

import android.content.Context
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.view.View
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import kotlin.test.*

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], manifest = Config.NONE, shadows = [ShadowNativeAdRegistration::class])
class NativeTemplateLayoutTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun ad(complete: Boolean): NativeAd {
        val ad = mock(NativeAd::class.java)
        `when`(ad.headline).thenReturn("Example headline that truncates naturally")
        if (complete) {
            `when`(ad.body).thenReturn("Ad description with enough words to exercise the layout.")
            `when`(ad.callToAction).thenReturn("Install now")
            `when`(ad.advertiser).thenReturn("Advertiser")
            `when`(ad.starRating).thenReturn(4.5)
            `when`(ad.price).thenReturn("Free")
            val icon = mock(NativeAd.Image::class.java)
            `when`(icon.drawable).thenReturn(ColorDrawable(Color.BLUE))
            `when`(ad.icon).thenReturn(icon)
        }
        return ad
    }

    private fun layout(view: NativeAdView, width: Int, height: Int) {
        val density = context.resources.displayMetrics.density
        val w = (width * density).toInt()
        val h = (height * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, w, h)
    }

    @Test fun everyTemplateBindsAssetsWithinBounds() {
        for (template in NativeTemplate.entries) for (width in listOf(320, 400)) for (direction in listOf(View.LAYOUT_DIRECTION_LTR, View.LAYOUT_DIRECTION_RTL)) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            view.layoutDirection = direction
            layout(view, width, template.height)
            val assets = listOfNotNull(view.headlineView, view.bodyView, view.callToActionView,
                view.iconView, view.advertiserView, view.starRatingView, view.priceView, view.mediaView, view.adChoicesView)
            for (asset in assets) {
                val rect = Rect(0, 0, asset.width, asset.height)
                view.offsetDescendantRectToMyCoords(asset, rect)
                assertTrue(rect.left >= 0 && rect.top >= 0 && rect.right <= view.width && rect.bottom <= view.height,
                    "${template.name} at $width: $rect outside ${view.width}x${view.height}")
            }
            assertTrue(view.headlineView!!.width > 0, template.name)
            assertTrue(view.callToActionView!!.width > 0, template.name)
            assertNotNull(view.adChoicesView)
            assertTrue(view.adChoicesView!!.width >= 24 * context.resources.displayMetrics.density)
            val expectedMedia = !template.isSmall && (template == NativeTemplate.medium1 || template == NativeTemplate.medium2 || !template.isMedium)
            assertEquals(expectedMedia, view.mediaView != null, template.name)
            view.mediaView?.let {
                val density = context.resources.displayMetrics.density
                assertTrue(it.width >= 120 * density && it.height >= 120 * density, "${template.name}: media must fit")
                val mediaBounds = Rect(0, 0, it.width, it.height)
                view.offsetDescendantRectToMyCoords(it, mediaBounds)
                for (asset in assets.filter { asset -> asset !== it }) {
                    val bounds = Rect(0, 0, asset.width, asset.height)
                    view.offsetDescendantRectToMyCoords(asset, bounds)
                    assertFalse(Rect.intersects(mediaBounds, bounds), "${template.name}: media overlaps an asset")
                }
            }
            view.destroy()
        }
    }

    @Test fun missingOptionalAssetsDoNotHideTheAdOrInventCtaText() {
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(ad(false))
            layout(view, 320, template.height)
            assertEquals(View.VISIBLE, view.visibility)
            assertEquals(View.INVISIBLE, view.callToActionView!!.visibility)
            assertEquals("", (view.callToActionView as TextView).text.toString())
            assertEquals(View.INVISIBLE, view.bodyView!!.visibility)
            assertNotNull(view.headlineView)
            view.destroy()
        }
    }

    @Test fun fullscreenLayoutsResizeAndPreserveTheirDistinctAssetOrder() {
        for (template in NativeTemplate.entries.filter { it.isFullscreen }) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            for (width in listOf(320, 600)) for (height in listOf(360, 640, 800)) {
                layout(view, width, height)
                fun bounds(asset: View): Rect {
                    val result = Rect(0, 0, asset.width, asset.height)
                    view.offsetDescendantRectToMyCoords(asset, result)
                    assertTrue(result.left >= 0 && result.top >= 0 && result.right <= view.width && result.bottom <= view.height,
                        "${template.name} at ${width}x$height: $result is outside host")
                    return result
                }
                val media = bounds(view.mediaView!!)
                val headline = bounds(view.headlineView!!)
                val button = bounds(view.callToActionView!!)
                for (asset in listOfNotNull(view.bodyView, view.iconView, view.advertiserView, view.priceView,
                    view.starRatingView, view.adChoicesView, view.headlineView, view.callToActionView)) {
                    assertFalse(Rect.intersects(media, bounds(asset)), "${template.name}: media overlap")
                }
                when (template) {
                    NativeTemplate.fullscreen1 -> assertTrue(headline.bottom <= media.top && media.bottom <= button.top)
                    NativeTemplate.fullscreen2 -> assertTrue(button.bottom <= headline.top && headline.bottom <= media.top)
                    NativeTemplate.fullscreen3, NativeTemplate.fullscreen4 -> assertTrue(media.bottom <= headline.top && headline.bottom <= button.top)
                    NativeTemplate.fullscreen5 -> assertTrue(button.bottom <= media.top && media.bottom <= headline.top)
                    else -> error("Not fullscreen")
                }
                if (template == NativeTemplate.fullscreen4) {
                    val density = context.resources.displayMetrics.density
                    assertEquals(((height - 48) * density / 2).toInt(), media.height())
                }
            }
            view.destroy()
        }
    }

    @Test fun everyTemplateRecolorsSecondaryAssetsAndRestoresDefaults() {
        for (template in NativeTemplate.entries) {
            val store = NativeAppearanceStore()
            store.startSession("session")
            store.applyColors("session", 1, mapOf("render" to NativePalette(body = 0xffffffff)))
            val view = NativeTemplateFactory(context, template, store).createNativeAd(
                ad(true), mutableMapOf("sessionId" to "session", "renderId" to "render"))
            val secondary = listOf(view.bodyView, view.advertiserView, view.starRatingView, view.priceView).filterIsInstance<TextView>()
            for (text in secondary) assertEquals(Color.WHITE, text.currentTextColor, template.name)
            store.applyColors("session", 2, mapOf("render" to NativePalette()))
            for (text in secondary) assertEquals(Color.DKGRAY, text.currentTextColor, template.name)
            view.destroy()
        }
    }

    @Test fun colorsResetAndStaleRevisionsCannotRepaintLiveViews() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        store.applyColors("session", 1, mapOf("render" to NativePalette(headline = 0xff00ff00)))
        val view = NativeTemplateFactory(context, NativeTemplate.small1, store).createNativeAd(
            ad(true), mutableMapOf("sessionId" to "session", "renderId" to "render"))
        assertEquals(Color.GREEN, (view.headlineView as TextView).currentTextColor)
        store.applyColors("session", 3, mapOf("render" to NativePalette(headline = 0xffff0000)))
        store.applyColors("session", 2, mapOf("render" to NativePalette(headline = 0xff0000ff)))
        assertEquals(Color.RED, (view.headlineView as TextView).currentTextColor)
        store.applyColors("session", 4, mapOf("render" to NativePalette()))
        assertEquals(Color.BLACK, (view.headlineView as TextView).currentTextColor)
        store.applyColors("session", 5, emptyMap())
        store.applyColors("session", 6, mapOf("render" to NativePalette(headline = 0xffff0000)))
        assertEquals(Color.BLACK, (view.headlineView as TextView).currentTextColor)
        view.destroy()
    }
}

// Ad registration needs a real Google Play services ad binder. Only that SDK
// boundary is replaced; asset registration, Android views and layout remain real.
@Implements(value = NativeAdView::class, isInAndroidSdk = false)
class ShadowNativeAdRegistration : org.robolectric.shadows.ShadowViewGroup() {
    @Implementation
    fun setNativeAd(ad: NativeAd) = Unit
}
