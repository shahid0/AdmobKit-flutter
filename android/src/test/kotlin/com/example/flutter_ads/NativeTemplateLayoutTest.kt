package com.example.flutter_ads

import android.content.Context
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
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
import org.robolectric.annotation.GraphicsMode
import java.io.File
import kotlin.test.*

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], manifest = Config.NONE, shadows = [ShadowNativeAdRegistration::class])
class NativeTemplateLayoutTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()

    private fun ad(complete: Boolean): NativeAd {
        val ad = mock(NativeAd::class.java)
        `when`(ad.headline).thenReturn("Example headline that truncates naturally")
        `when`(ad.starRating).thenReturn(null)
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

    private fun layout(view: NativeAdView, width: Int, height: Int? = null) {
        val density = context.resources.displayMetrics.density
        val measured = view.findViewById<NativeTemplatePanel>(R.id.ad_card_container).configure(
            NativeLayoutRequest(width = width.toDouble(), height = height?.toDouble(),
                headlineSize = 15.0, bodySize = 12.0, metadataSize = 11.0, actionSize = 13.0))
        val w = (width * density).toInt()
        val h = kotlin.math.ceil(measured * density).toInt()
        view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
        view.layout(0, 0, w, h)
    }

    @Test fun everyTemplateBindsAssetsWithinBounds() {
        for (template in NativeTemplate.entries) for (width in listOf(320, 400)) for (direction in listOf(View.LAYOUT_DIRECTION_LTR, View.LAYOUT_DIRECTION_RTL)) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            view.layoutDirection = direction
            layout(view, width, if (template.isFullscreen) 640 else null)
            val assets = listOfNotNull(view.headlineView, view.bodyView, view.callToActionView,
                view.iconView, view.advertiserView, view.starRatingView, view.priceView, view.mediaView, view.adChoicesView)
                .filter { it.visibility != View.GONE }
            for (asset in assets) {
                val rect = Rect(0, 0, asset.width, asset.height)
                view.offsetDescendantRectToMyCoords(asset, rect)
                assertTrue(rect.left >= 0 && rect.top >= 0 && rect.right <= view.width && rect.bottom <= view.height,
                    "${template.name} at $width: $rect outside ${view.width}x${view.height}")
            }
            assertTrue(view.headlineView!!.width > 0, template.name)
            assertTrue(view.callToActionView!!.width > 0, template.name)
            for (text in listOf(view.headlineView, view.bodyView).filterIsInstance<TextView>().filter { it.visibility != View.GONE }) {
                assertTrue(text.layout.getLineBottom(text.layout.lineCount - 1) <= text.height,
                    "${template.name}: visible text must fit its measured height")
            }
            val badge = view.findViewById<TextView>(R.id.ad_attribution_badge)
            assertEquals("Ad", badge.text.toString())
            assertTrue(badge.width >= 15 * context.resources.displayMetrics.density)
            assertTrue(badge.height >= 15 * context.resources.displayMetrics.density)
            val badgeBounds = Rect(0, 0, badge.width, badge.height)
            view.offsetDescendantRectToMyCoords(badge, badgeBounds)
            val corner = (24 * context.resources.displayMetrics.density).toInt()
            val sdkCorner = Rect(view.width - corner, 0, view.width, corner)
            for (asset in assets.filter { it !== view.mediaView }) {
                val rect = Rect(0, 0, asset.width, asset.height)
                view.offsetDescendantRectToMyCoords(asset, rect)
                assertFalse(Rect.intersects(rect, sdkCorner), "${template.name}: asset covers SDK AdChoices corner in direction $direction")
            }
            assertFalse(Rect.intersects(badgeBounds, sdkCorner), "${template.name}: badge covers SDK AdChoices corner")
            assertNull(view.adChoicesView, "AdChoices placement belongs to the SDK, not a custom row")
            val expectedMedia = template.hasMedia
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

    @Test
    fun headlineWrapsAndLongBodyRemainsVisibleWithNativeEndEllipsis() {
        val view = NativeTemplateLayout(context, NativeTemplate.feedMediaFirst).build(ad(true))
        layout(view, 320)
        val headline = view.headlineView as TextView
        val body = view.bodyView as TextView
        assertTrue(headline.layout.lineCount >= 2)
        assertEquals(View.VISIBLE, body.visibility)
        assertEquals(1, body.layout.lineCount)
        assertEquals(TextUtils.TruncateAt.END, body.ellipsize)
        assertTrue(body.layout.getEllipsisCount(0) > 0)
        assertEquals(ad(true).body, body.text.toString())
        assertTrue(headline.layout.getLineBottom(headline.layout.lineCount - 1) <= headline.height)
        val rating = view.starRatingView!!
        val price = view.priceView!!
        val ratingBounds = Rect(0, 0, rating.width, rating.height)
        val priceBounds = Rect(0, 0, price.width, price.height)
        view.offsetDescendantRectToMyCoords(rating, ratingBounds)
        view.offsetDescendantRectToMyCoords(price, priceBounds)
        assertTrue(priceBounds.left - ratingBounds.right >= 8 * context.resources.displayMetrics.density)
        view.destroy()
    }

    @Test fun missingIconDoesNotLeaveAReservedBlankColumn() {
        val view = NativeTemplateLayout(context, NativeTemplate.feedMediaFirst).build(ad(false))
        layout(view, 320)
        assertNull(view.iconView)
        assertTrue(view.headlineView!!.width >= 280 * context.resources.displayMetrics.density)
        view.destroy()
    }

    @Test fun everyCatalogCompositionHasDistinctGeometryAtPhoneAndTabletWidths() {
        for (width in listOf(320, 360, 400, 600)) {
            val signatures = mutableMapOf<List<Rect?>, NativeTemplate>()
            for (template in NativeTemplate.entries) {
                val fixture = ad(true)
                `when`(fixture.headline).thenReturn("Focus timer")
                `when`(fixture.body).thenReturn("Stay focused")
                val view = NativeTemplateLayout(context, template).build(fixture)
                layout(view, width, if (template.isFullscreen) 640 else null)
                val signature = listOf(view.headlineView, view.bodyView, view.iconView, view.callToActionView,
                    view.mediaView, view.starRatingView, view.priceView).map { asset ->
                    asset?.let { Rect(0, 0, it.width, it.height).also { rect ->
                        view.offsetDescendantRectToMyCoords(it, rect)
                    } }
                }
                val previous = signatures.put(signature, template)
                assertNull(previous, "${template.name} duplicates $previous at width $width")
                view.destroy()
            }
        }
    }

    @Test fun namesMatchAssetOrderIncludingVideoInCards() {
        for (video in listOf(false, true)) for (template in NativeTemplate.entries) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn("Stay focused")
            if (video) {
                val content = mock(com.google.android.gms.ads.MediaContent::class.java)
                `when`(content.hasVideoContent()).thenReturn(true)
                `when`(fixture.mediaContent).thenReturn(content)
            }
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 360, if (template.isFullscreen) 640 else null)
            fun bounds(asset: View) = Rect(0, 0, asset.width, asset.height).also {
                view.offsetDescendantRectToMyCoords(asset, it)
            }
            val identity = bounds(view.headlineView!!)
            val action = bounds(view.callToActionView!!)
            val icon = bounds(view.iconView!!)
            assertEquals(template.trailingIcon, icon.left > identity.right, template.name)
            if (template.sideAction) {
                assertSame(view.iconView!!.parent, view.callToActionView!!.parent, template.name)
                if (template.leadingAction) assertTrue(action.right <= icon.left, template.name)
                else assertTrue(action.left >= maxOf(identity.right, icon.right), template.name)
            } else if (template.actionFirst) assertTrue(action.bottom <= identity.top, template.name)
            else assertTrue(identity.bottom <= action.top, template.name)
            view.mediaView?.let { asset ->
                val media = bounds(asset)
                when {
                    template == NativeTemplate.splitMediaLeft -> assertTrue(media.right <= minOf(identity.left, icon.left, action.left), template.name)
                    template == NativeTemplate.splitMediaRight -> assertTrue(media.left >= maxOf(identity.right, icon.right, action.right), template.name)
                    template.actionFirst -> assertTrue(identity.bottom <= media.top, template.name)
                    template.mediaFirst -> assertTrue(media.bottom <= identity.top, template.name)
                    template.actionMiddle -> assertTrue(action.bottom <= media.top, template.name)
                    template.sideAction -> assertTrue(identity.bottom <= media.top && action.bottom <= media.top, template.name)
                    else -> assertTrue(identity.bottom <= media.top && media.bottom <= action.top, template.name)
                }
            }
            view.destroy()
        }
    }

    @Test fun shortCopyUsesOneLineAndIconMatchesTheIdentityStack() {
        val fixture = ad(true)
        `when`(fixture.headline).thenReturn("Focus timer")
        `when`(fixture.body).thenReturn("Stay focused")
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 360, if (template.isFullscreen) 640 else null)
            assertEquals((if (template.isSplit) 36 else 48) * context.resources.displayMetrics.density, view.iconView!!.width.toFloat(), template.name)
            assertEquals(1, (view.headlineView as TextView).layout.lineCount, template.name)
            if (view.bodyView!!.visibility != View.GONE) assertEquals(1, (view.bodyView as TextView).layout.lineCount, template.name)
            assertEquals(8 * context.resources.displayMetrics.density, (view.callToActionView!!.background as GradientDrawable).cornerRadius)
            view.destroy()
        }
    }

    @Test fun sideActionsReclaimMissingIconAndActionWidthWithoutMovingTheRemainingAssets() {
        for (template in NativeTemplate.entries.filter { it.sideAction }) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn("Stay focused")
            val complete = NativeTemplateLayout(context, template).build(fixture)
            layout(complete, 360, if (template.isFullscreen) 640 else null)
            val completeWidth = complete.headlineView!!.width
            complete.destroy()
            `when`(fixture.icon).thenReturn(null)
            val noIcon = NativeTemplateLayout(context, template).build(fixture)
            layout(noIcon, 360, if (template.isFullscreen) 640 else null)
            assertNull(noIcon.iconView, template.name)
            assertTrue(noIcon.headlineView!!.width > completeWidth, template.name)
            assertSame(noIcon.headlineView!!.parent.parent, noIcon.callToActionView!!.parent, template.name)
            noIcon.destroy()
            `when`(fixture.callToAction).thenReturn(null)
            val noAction = NativeTemplateLayout(context, template).build(fixture)
            layout(noAction, 360, if (template.isFullscreen) 640 else null)
            assertEquals(View.GONE, noAction.callToActionView!!.visibility, template.name)
            val expectedWidth = if (noAction.mediaView != null && template.mediaFirst) 344 else 320
            assertEquals(expectedWidth * context.resources.displayMetrics.density, noAction.headlineView!!.width.toFloat(), template.name)
            noAction.destroy()
        }
    }

    @Test fun compactIdentityKeepsSmallTypographyTightGapsAndReadableAdControls() {
        val fixture = ad(true)
        `when`(fixture.headline).thenReturn("Focus timer")
        `when`(fixture.body).thenReturn("Stay focused")
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 360, if (template.isFullscreen) 640 else null)
            val density = context.resources.displayMetrics.density
            fun bounds(asset: View) = Rect(0, 0, asset.width, asset.height).also {
                view.offsetDescendantRectToMyCoords(asset, it)
            }
            assertEquals((if (template.isSplit) 36 else 48) * density, view.iconView!!.width.toFloat(), template.name)
            assertEquals(15 * density, (view.headlineView as TextView).textSize, template.name)
            assertEquals(12 * density, (view.bodyView as TextView).textSize, template.name)
            assertEquals(11 * density, (view.starRatingView as TextView).textSize, template.name)
            assertEquals(13 * density, (view.callToActionView as TextView).textSize, template.name)
            assertEquals(View.VISIBLE, view.bodyView!!.visibility, template.name)
            assertEquals(2 * density, (bounds(view.bodyView!!).top - bounds(view.headlineView!!).bottom).toFloat(), template.name)
            val badge = view.findViewById<View>(R.id.ad_attribution_badge)
            assertTrue(badge.width >= 15 * density && badge.height >= 15 * density, template.name)
            assertTrue(view.callToActionView!!.height >= (if (template.isFullscreen) 48 else 44) * density, template.name)
            view.destroy()
        }
    }

    @Test fun protectedCopyAndScaledFontsGrowRatherThanTruncate() {
        for (template in NativeTemplate.entries) for (width in listOf(320, 360, 400, 600)) for (scale in listOf(1.0, 1.5, 2.0)) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("WWWWWWWWWWWWWWWWWWWWWWWWW")
            `when`(fixture.body).thenReturn("A description that must remain fully visible before the ninety character truncation limit.")
            `when`(fixture.callToAction).thenReturn("Discover it now")
            val view = NativeTemplateLayout(context, template).build(fixture)
            val panel = view.findViewById<NativeTemplatePanel>(R.id.ad_card_container)
            val height = panel.configure(NativeLayoutRequest(width = width.toDouble(), headlineSize = 15 * scale,
                bodySize = 12 * scale, metadataSize = 11 * scale, actionSize = 13 * scale))
            val density = context.resources.displayMetrics.density
            val w = (width * density).toInt()
            val h = kotlin.math.ceil(height * density).toInt()
            view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
            view.layout(0, 0, w, h)
            if (template.sideAction) {
                assertSame(view.iconView!!.parent, view.callToActionView!!.parent,
                    "${template.name} at $width/$scale: side action migrated out of its row")
            }
            if (template.isSplit) {
                assertEquals(120 * density, view.mediaView!!.width.toFloat(), template.name)
                assertEquals(120 * density, view.mediaView!!.height.toFloat(),
                    "${template.name}: long copy must not stretch the media viewport")
            }
            for (text in listOf(view.headlineView, view.callToActionView).filterIsInstance<TextView>().filter { it.visibility != View.GONE }) {
                val last = text.layout.lineCount - 1
                assertEquals(text.text.length, text.layout.getLineEnd(last), "${template.name} at $width/$scale: protected copy lost")
                assertEquals(0, text.layout.getEllipsisCount(last), template.name)
                assertTrue(text.layout.getLineBottom(last) <= text.height, template.name)
                val bounds = Rect(0, 0, text.width, text.height)
                view.offsetDescendantRectToMyCoords(text, bounds)
                assertTrue(bounds.bottom <= view.height && bounds.right <= view.width, template.name)
            }
            view.destroy()
        }
    }

    @Test fun measurementRegistryRejectsReleasedRendersAndStaleSessions() {
        val store = NativeAppearanceStore()
        store.startSession("measure")
        store.applyStyle("measure", 1, mapOf("render" to NativeStyleData()))
        val fixture = ad(true)
        `when`(fixture.headline).thenReturn("Focus timer")
        `when`(fixture.body).thenReturn("Stay focused")
        val view = NativeTemplateFactory(context, NativeTemplate.cardContentTop, store).createNativeAd(fixture,
            mutableMapOf("sessionId" to "measure", "renderId" to "render"))
        val request = NativeLayoutRequest(width = 360.0, headlineSize = 15.0, bodySize = 12.0, metadataSize = 11.0, actionSize = 13.0)
        val measuredHeight = store.layoutNativeAd("measure", "render", request)
        assertTrue(measuredHeight > 0 && measuredHeight < NativeTemplate.cardContentTop.height)
        store.applyStyle("measure", 2, emptyMap())
        assertFailsWith<IllegalStateException> { store.layoutNativeAd("measure", "render", request) }
        store.startSession("new")
        assertFailsWith<IllegalStateException> { store.layoutNativeAd("measure", "render", request) }
        view.destroy()
    }

    @Test fun suppliedBodyRemainsVisibleOnOneLineAcrossEveryTemplateWidthAndScale() {
        for (template in NativeTemplate.entries) for (width in listOf(320, 360, 400, 600)) for (scale in listOf(1.0, 1.5, 2.0)) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn("Notes, plans and ideas.")
            val view = NativeTemplateLayout(context, template).build(fixture)
            val panel = view.findViewById<NativeTemplatePanel>(R.id.ad_card_container)
            fun configure() {
                val measured = panel.configure(NativeLayoutRequest(width = width.toDouble(), headlineSize = 15 * scale,
                    bodySize = 12 * scale, metadataSize = 11 * scale, actionSize = 13 * scale))
                val density = context.resources.displayMetrics.density
                val w = (width * density).toInt()
                val h = kotlin.math.ceil(measured * density).toInt()
                view.measure(View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY))
                view.layout(0, 0, w, h)
            }
            configure()
            val body = view.bodyView as TextView
            assertEquals(1, body.maxLines, template.name)
            assertEquals(View.VISIBLE, body.visibility, "${template.name} at $width/$scale: supplied body disappeared")
            assertEquals(TextUtils.TruncateAt.END, body.ellipsize, template.name)
            assertEquals(fixture.body, body.text.toString(), "${template.name}: SDK text was manually modified")
            assertEquals(1, body.layout.lineCount, template.name)
            assertTrue(body.layout.getLineBottom(0) <= body.height, template.name)
            view.destroy()
        }
    }

    @Test fun nativeBodyEllipsisReflowsAfterResizingWithoutHidingOrChangingText() {
        val fixture = ad(true)
        `when`(fixture.body).thenReturn("A long description that cannot fit beside the app icon at a phone width.")
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 320)
            val body = view.bodyView as TextView
            assertEquals(View.VISIBLE, body.visibility, template.name)
            assertTrue(body.layout.getEllipsisCount(0) > 0, template.name)
            layout(view, 1200)
            assertEquals(View.VISIBLE, body.visibility, template.name)
            assertEquals(1, body.layout.lineCount, template.name)
            assertEquals(body.text.length, body.layout.getLineEnd(0), template.name)
            assertEquals(0, body.layout.getEllipsisCount(0), template.name)
            layout(view, 320)
            assertEquals(View.VISIBLE, body.visibility, template.name)
            assertTrue(body.layout.getEllipsisCount(0) > 0, template.name)
            assertEquals(fixture.body, body.text.toString(), template.name)
            view.destroy()
        }
    }

    @Test fun bodyWithExplicitLineBreaksIsHandledByTheNativeTextViewWithoutHiding() {
        for (separator in listOf("\n", "\r", "\u0085", "\u2028", "\u2029")) {
            val fixture = ad(true)
            `when`(fixture.body).thenReturn("First${separator}Second")
            val view = NativeTemplateLayout(context, NativeTemplate.feedMediaFirst).build(fixture)
            layout(view, 1200)
            val body = view.bodyView as TextView
            assertEquals(View.VISIBLE, body.visibility)
            assertEquals(fixture.body, body.text.toString())
            assertEquals(1, body.layout.lineCount)
            view.destroy()
        }
    }

    @Test fun missingAndEmptyBodiesCollapseWithoutReservingATextLine() {
        for (template in NativeTemplate.entries) for (value in listOf(null, "")) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn(value)
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 360, if (template.isFullscreen) 640 else null)
            assertEquals(View.GONE, view.bodyView!!.visibility, template.name)
            assertEquals("", (view.bodyView as TextView).text.toString(), template.name)
            view.destroy()
        }
    }

    @Test fun videoIsNeverDiscardedByANonMediaComposition() {
        val fixture = ad(true)
        val mediaContent = mock(com.google.android.gms.ads.MediaContent::class.java)
        `when`(mediaContent.hasVideoContent()).thenReturn(true)
        `when`(fixture.mediaContent).thenReturn(mediaContent)
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 360, if (template.isFullscreen) 640 else null)
            assertNotNull(view.mediaView, template.name)
            assertTrue(view.mediaView!!.height >= (if (template.isSplit) 120 else 144) * context.resources.displayMetrics.density, template.name)
            view.destroy()
        }
    }

    @Test fun attributionDoesNotReserveAHeaderAndMetadataFollowsHeadline() {
        val view = NativeTemplateLayout(context, NativeTemplate.feedMediaFirst).build(ad(true))
        layout(view, 320)
        fun bounds(asset: View): Rect = Rect(0, 0, asset.width, asset.height).also {
            view.offsetDescendantRectToMyCoords(asset, it)
        }
        val badge = bounds(view.findViewById(R.id.ad_attribution_badge))
        val media = bounds(view.mediaView!!)
        val headline = bounds(view.headlineView!!)
        val rating = bounds(view.starRatingView!!)
        assertEquals((8 * context.resources.displayMetrics.density).toInt(), media.top)
        assertTrue(badge.top >= headline.bottom)
        assertFalse(media.contains(badge))
        assertNull(view.advertiserView)
        assertTrue(rating.top >= headline.bottom)
        assertFalse(Rect.intersects(badge, rating))
        assertNull(view.adChoicesView)
        view.destroy()
    }

    @Test fun absentMetadataCollapsesWithoutAnEmptyFooter() {
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(ad(false))
            layout(view, 320, if (template.isFullscreen) 640 else null)
            assertNull(view.advertiserView)
            assertNull(view.starRatingView)
            assertNull(view.priceView)
            val badge = view.findViewById<View>(R.id.ad_attribution_badge)
            assertEquals(View.VISIBLE, badge.visibility, template.name)
            assertTrue(badge.height > 0, template.name)
            view.destroy()
        }
    }

    @Test
    fun renderCatalogFixturesForVisualInspection() {
        val output = File(buildOutput(), "native-design").apply { mkdirs() }
        val density = context.resources.displayMetrics.density
        val cardWidth = (360 * density).toInt()
        val gutter = (20 * density).toInt()
        val previews = mutableListOf<Pair<NativeTemplate, Bitmap>>()
        for (template in NativeTemplate.entries) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn(if (template.isSplit) "Stay focused" else "Notes, plans and ideas.")
            `when`(fixture.advertiser).thenReturn("Clarity")
            `when`(fixture.callToAction).thenReturn("Install")
            `when`(fixture.icon!!.drawable).thenReturn(BitmapDrawable(context.resources, iconFixture()))
            val store = NativeAppearanceStore()
            store.startSession("visual")
            val palette = NativeStyleData()
            store.applyStyle("visual", 1, mapOf("card" to palette))
            val view = NativeTemplateFactory(context, template, store).createNativeAd(fixture,
                mutableMapOf("sessionId" to "visual", "renderId" to "card"))
            // Only the SDK creative/binder boundary is simulated. All typography,
            // layout, clipping, palettes and asset registration are production views.
            view.mediaView?.addView(ImageView(context).apply {
                setImageBitmap(creativeFixture(template.isFullscreen))
                scaleType = ImageView.ScaleType.FIT_CENTER
            }, ViewGroup.LayoutParams(-1, -1))
            val height = if (template.isFullscreen) 640 else null
            layout(view, 360, height)
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
            File(output, "${template.name}-light.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            previews.add(template to bitmap)
            if (template == NativeTemplate.feedMediaFirst) {
                store.applyStyle("visual", 2, mapOf("card" to NativeStyleData(
                    background = 0xff0f0f0f, headline = 0xfff1f1f1, body = 0xffaaaaaa,
                    callToActionBackground = 0xfff1f1f1, callToActionText = 0xff0f0f0f)))
                val dark = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                view.draw(Canvas(dark))
                File(output, "feedMediaFirst-dark.png").outputStream().use { dark.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
            view.destroy()
        }
        fun sheet(items: List<Pair<NativeTemplate, Bitmap>>, columns: Int, filename: String) {
            val rows = items.chunked(columns)
            val rowHeights = rows.map { row -> row.maxOf { it.second.height } + gutter + (28 * density).toInt() }
            val image = Bitmap.createBitmap((cardWidth + gutter) * columns + gutter, rowHeights.sum() + gutter, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(image)
            canvas.drawColor(0xffeceff1.toInt())
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.DKGRAY; textSize = 14 * density; typeface = Typeface.DEFAULT_BOLD
            }
            for ((index, item) in items.withIndex()) {
                val x = gutter + (index % columns) * (cardWidth + gutter)
                val y = gutter + rowHeights.take(index / columns).sum()
                canvas.drawText(item.first.name, x.toFloat(), y + 16 * density, titlePaint)
                canvas.drawBitmap(item.second, x.toFloat(), y + 28 * density, null)
            }
            File(output, filename).outputStream().use { image.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        sheet(previews, 3, "catalog.png")
        sheet(previews.filter { it.first.sideAction }, 2, "side-cta-catalog.png")
        sheet(previews.filter { it.first.isSplit }, 2, "smart-media-catalog.png")
    }

    @Test fun smartMediaStaysHorizontalAndSmallerThanFeedWithOrdinaryCopy() {
        for (width in listOf(320, 360, 400, 600)) for (video in listOf(false, true)) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            `when`(fixture.body).thenReturn("Stay focused")
            `when`(fixture.callToAction).thenReturn("Install")
            val content = mock(com.google.android.gms.ads.MediaContent::class.java)
            `when`(content.hasVideoContent()).thenReturn(video)
            `when`(fixture.mediaContent).thenReturn(content)
            val feed = NativeTemplateLayout(context, NativeTemplate.feedMediaFirst).build(fixture)
            layout(feed, width)
            for (template in NativeTemplate.entries.filter { it.isSplit }) {
                val view = NativeTemplateLayout(context, template).build(fixture)
                layout(view, width)
                assertTrue(view.height < feed.height, "${template.name}: must be smaller than feed at $width/video=$video")
                assertTrue(view.height <= 160 * context.resources.displayMetrics.density, template.name)
                assertEquals(120 * context.resources.displayMetrics.density, view.mediaView!!.width.toFloat(), template.name)
                assertEquals(View.VISIBLE, view.bodyView!!.visibility, template.name)
                assertSame(content, view.mediaView!!.mediaContent, template.name)
                val media = Rect(0, 0, view.mediaView!!.width, view.mediaView!!.height)
                view.offsetDescendantRectToMyCoords(view.mediaView!!, media)
                for (asset in listOfNotNull(view.iconView, view.headlineView, view.bodyView, view.callToActionView,
                    view.starRatingView, view.priceView, view.findViewById(R.id.ad_attribution_badge))) {
                    val bounds = Rect(0, 0, asset.width, asset.height)
                    view.offsetDescendantRectToMyCoords(asset, bounds)
                    if (template == NativeTemplate.splitMediaLeft) assertTrue(media.right <= bounds.left, template.name)
                    else assertTrue(bounds.right <= media.left, template.name)
                }
                view.destroy()
            }
            feed.destroy()
        }
    }

    @Test fun smartMediaReclaimsMissingIconAndDoesNotInventAnAction() {
        for (template in NativeTemplate.entries.filter { it.isSplit }) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Focus timer")
            val complete = NativeTemplateLayout(context, template).build(fixture)
            layout(complete, 320)
            val completeWidth = complete.headlineView!!.width
            complete.destroy()
            `when`(fixture.icon).thenReturn(null)
            `when`(fixture.callToAction).thenReturn(null)
            val view = NativeTemplateLayout(context, template).build(fixture)
            layout(view, 320)
            assertNull(view.iconView, template.name)
            assertEquals(View.GONE, view.callToActionView!!.visibility, template.name)
            assertTrue(view.headlineView!!.width > completeWidth, template.name)
            assertNotNull(view.mediaView, template.name)
            assertEquals(View.VISIBLE, view.findViewById<View>(R.id.ad_attribution_badge).visibility, template.name)
            view.destroy()
        }
    }

    private fun buildOutput() = System.getProperty("nativeDesignOutput")
        ?: File(System.getProperty("user.dir"), "build/reports").path

    private fun creativeFixture(portrait: Boolean = false): Bitmap {
        val bitmap = Bitmap.createBitmap(960, if (portrait) 1440 else 540, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.shader = LinearGradient(0f, 0f, 960f, 540f, 0xff213f35.toInt(), 0xffc9dfb0.toInt(), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, bitmap.width.toFloat(), bitmap.height.toFloat(), paint)
        paint.shader = null
        paint.color = 0x33ffffff
        canvas.drawCircle(850f, 100f, 240f, paint)
        canvas.drawCircle(820f, 120f, 150f, paint)
        paint.color = Color.WHITE
        paint.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        paint.textSize = 36f
        canvas.drawText("C L A R I T Y", 70f, 110f, paint)
        paint.textSize = 78f
        canvas.drawText("A little less noise.", 70f, 280f, paint)
        canvas.drawText("A lot more focus.", 70f, 375f, paint)
        return bitmap
    }

    private fun iconFixture(): Bitmap {
        val bitmap = Bitmap.createBitmap(80, 80, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(0xff213f35.toInt())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 56f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        }
        canvas.drawText("C", 40f, 60f, paint)
        return bitmap
    }

    @Test fun missingOptionalAssetsDoNotHideTheAdOrInventCtaText() {
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(ad(false))
            layout(view, 320, if (template.isFullscreen) 640 else null)
            assertEquals(View.VISIBLE, view.visibility)
            assertEquals(View.GONE, view.callToActionView!!.visibility)
            assertEquals("", (view.callToActionView as TextView).text.toString())
            assertEquals(View.GONE, view.bodyView!!.visibility)
            assertNotNull(view.headlineView)
            view.destroy()
        }
    }

    @Test fun fullscreenLayoutsResizeAndPreserveTheirDistinctAssetOrder() {
        for (template in NativeTemplate.entries.filter { it.isFullscreen }) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            for (width in listOf(320, 600)) for (height in listOf(400, 640, 800)) {
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
                    view.starRatingView, view.adChoicesView, view.headlineView, view.callToActionView).filter { it.visibility != View.GONE }) {
                    assertFalse(Rect.intersects(media, bounds(asset)), "${template.name}: media overlap")
                }
                when (template) {
                    NativeTemplate.fullscreenMediaFirst, NativeTemplate.fullscreenTrailingIcon -> assertTrue(media.bottom <= headline.top && headline.bottom <= button.top)
                    NativeTemplate.fullscreenMediaSideCta -> assertTrue(media.bottom <= headline.top && media.bottom <= button.top)
                    NativeTemplate.fullscreenContentFirst -> assertTrue(headline.bottom <= media.top && media.bottom <= button.top)
                    NativeTemplate.fullscreenActionMiddle -> assertTrue(headline.bottom <= button.top && button.bottom <= media.top)
                    else -> error("Not fullscreen")
                }
            }
            view.destroy()
        }
    }

    @Test fun everyTemplateRecolorsSecondaryAssetsAndRestoresDefaults() {
        for (template in NativeTemplate.entries) {
            val store = NativeAppearanceStore()
            store.startSession("session")
            store.applyStyle("session", 1, mapOf("render" to NativeStyleData(body = 0xffffffff)))
            val view = NativeTemplateFactory(context, template, store).createNativeAd(
                ad(true), mutableMapOf("sessionId" to "session", "renderId" to "render"))
            val secondary = listOf(view.bodyView, view.advertiserView, view.starRatingView, view.priceView).filterIsInstance<TextView>()
            for (text in secondary) assertEquals(Color.WHITE, text.currentTextColor, template.name)
            store.applyStyle("session", 2, mapOf("render" to NativeStyleData()))
            for (text in secondary) assertEquals(NativeTemplateStyle.secondary, text.currentTextColor, template.name)
            view.destroy()
        }
    }

    @Test fun fullscreenRejectsInsufficientMediaSpaceInsteadOfClippingAssets() {
        for (template in NativeTemplate.entries.filter { it.isFullscreen }) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            layout(view, 320, 640)
            val density = context.resources.displayMetrics.density
            val nonMediaHeight = 640 - (view.mediaView!!.height / density).toInt()
            layout(view, 320, nonMediaHeight + 144)
            assertEquals(144 * density, view.mediaView!!.height.toFloat(), template.name)
            assertFailsWith<IllegalArgumentException> { layout(view, 320, nonMediaHeight + 143) }
            view.destroy()
        }
    }

    @Test fun colorsResetAndStaleRevisionsCannotRepaintLiveViews() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        store.applyStyle("session", 1, mapOf("render" to NativeStyleData(headline = 0xff00ff00)))
        val view = NativeTemplateFactory(context, NativeTemplate.cardContentTop, store).createNativeAd(
            ad(true), mutableMapOf("sessionId" to "session", "renderId" to "render"))
        assertEquals(Color.GREEN, (view.headlineView as TextView).currentTextColor)
        store.applyStyle("session", 3, mapOf("render" to NativeStyleData(headline = 0xffff0000)))
        store.applyStyle("session", 2, mapOf("render" to NativeStyleData(headline = 0xff0000ff)))
        assertEquals(Color.RED, (view.headlineView as TextView).currentTextColor)
        store.applyStyle("session", 4, mapOf("render" to NativeStyleData()))
        assertEquals(NativeTemplateStyle.headline, (view.headlineView as TextView).currentTextColor)
        store.applyStyle("session", 5, emptyMap())
        store.applyStyle("session", 6, mapOf("render" to NativeStyleData(headline = 0xffff0000)))
        assertEquals(NativeTemplateStyle.headline, (view.headlineView as TextView).currentTextColor)
        view.destroy()
    }

    @Test fun ctaRadiusUpdatesClampAndResetWithoutChangingButtonBoundsOrBadge() {
        for (template in NativeTemplate.entries) {
            val store = NativeAppearanceStore()
            store.startSession("shape")
            store.applyStyle("shape", 1, mapOf("render" to NativeStyleData()))
            val view = NativeTemplateFactory(context, template, store).createNativeAd(ad(true),
                mutableMapOf("sessionId" to "shape", "renderId" to "render"))
            layout(view, 320, if (template.isFullscreen) 640 else null)
            val cta = view.callToActionView!!
            val size = cta.width to cta.height
            val original = (cta.background as GradientDrawable).cornerRadius
            val badge = view.findViewById<View>(R.id.ad_attribution_badge)
            val badgeRadius = (badge.background as GradientDrawable).cornerRadius
            for ((index, radius) in listOf(0.0, 6.5, Double.MAX_VALUE, null).withIndex()) {
                store.applyStyle("shape", (index + 2).toLong(), mapOf("render" to NativeStyleData(
                    callToActionCornerRadius = radius, callToActionBackground = 0xff00ff00)))
                layout(view, 320, if (template.isFullscreen) 640 else null)
                val expected = radius?.let { (it * context.resources.displayMetrics.density).toFloat().coerceAtMost(cta.height / 2f) } ?: original
                assertEquals(expected, (cta.background as GradientDrawable).cornerRadius, template.name)
                assertEquals(size, cta.width to cta.height, template.name)
                assertEquals(badgeRadius, (badge.background as GradientDrawable).cornerRadius)
            }
            store.applyStyle("shape", 4, mapOf("render" to NativeStyleData(callToActionCornerRadius = 0.0)))
            assertEquals(original, (cta.background as GradientDrawable).cornerRadius)
            view.destroy()
        }
    }

    @Test @Config(qualifiers = "xhdpi")
    fun backgroundGeometrySurvivesStylingAtDoubleDensity() {
        assertBackgroundGeometrySurvivesStyling(2f)
    }

    @Test @Config(qualifiers = "xxhdpi")
    fun backgroundGeometrySurvivesStylingAtTripleDensity() {
        assertBackgroundGeometrySurvivesStyling(3f)
    }

    private fun assertBackgroundGeometrySurvivesStyling(density: Float) {
        assertEquals(density, context.resources.displayMetrics.density)
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(ad(true))
            layout(view, 320, if (template.isFullscreen) 640 else null)
            val card = view.findViewById<View>(R.id.ad_card_container)
            val cta = view.callToActionView!!
            val cardRadius = (card.background as GradientDrawable).cornerRadius
            val ctaRadius = (cta.background as GradientDrawable).cornerRadius
            val bounds = listOf(card, cta).map { Rect(it.left, it.top, it.right, it.bottom) }
            assertEquals(12f * density, cardRadius, template.name)
            val store = NativeAppearanceStore()
            store.startSession("density")
            store.applyStyle("density", 1, mapOf("render" to NativeStyleData()))
            store.attach(view, mapOf("sessionId" to "density", "renderId" to "render"))
            assertEquals(cardRadius, (card.background as GradientDrawable).cornerRadius,
                "${template.name}: initial attachment must not scale the card again")
            assertEquals(ctaRadius, (cta.background as GradientDrawable).cornerRadius, template.name)
            for ((index, color) in listOf(0xff0f0f0fL, 0xffeeeeeeL, null).withIndex()) {
                val radius = if (color == null) null else 6.5
                store.applyStyle("density", (index + 2).toLong(), mapOf("render" to NativeStyleData(
                    background = color, callToActionBackground = color, callToActionCornerRadius = radius)))
                layout(view, 320, if (template.isFullscreen) 640 else null)
                assertEquals(cardRadius, (card.background as GradientDrawable).cornerRadius,
                    "${template.name}: color updates and reset must preserve card geometry")
                assertEquals(radius?.let { (it * density).toFloat().coerceAtMost(ctaRadius) } ?: ctaRadius,
                    (cta.background as GradientDrawable).cornerRadius, template.name)
                assertEquals(color?.toInt(), card.backgroundTintList?.defaultColor, template.name)
                assertEquals(bounds, listOf(card, cta).map { Rect(it.left, it.top, it.right, it.bottom) }, template.name)
            }
            view.destroy()
        }
    }

    @Test @Config(qualifiers = "xhdpi")
    fun fractionalCtaRadiusUsesLogicalPixelsAtHighDensity() {
        val store = NativeAppearanceStore()
        store.startSession("density")
        store.applyStyle("density", 1, mapOf("render" to NativeStyleData(callToActionCornerRadius = 6.5)))
        val view = NativeTemplateFactory(context, NativeTemplate.cardContentTop, store).createNativeAd(ad(true),
            mutableMapOf("sessionId" to "density", "renderId" to "render"))
        assertEquals(2f, context.resources.displayMetrics.density)
        assertEquals(13f, (view.callToActionView!!.background as GradientDrawable).cornerRadius)
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
