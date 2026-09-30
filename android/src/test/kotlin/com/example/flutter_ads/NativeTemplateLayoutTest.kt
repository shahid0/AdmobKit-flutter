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
            for (text in listOf(view.headlineView, view.bodyView).filterIsInstance<TextView>()) {
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

    @Test
    fun readableCopyAndSeparatedMetadataReplaceTheSingleLineLayout() {
        val view = NativeTemplateLayout(context, NativeTemplate.large1).build(ad(true))
        layout(view, 320, NativeTemplate.large1.height)
        val headline = view.headlineView as TextView
        val body = view.bodyView as TextView
        assertTrue(headline.layout.lineCount >= 2)
        assertTrue(body.layout.lineCount >= 2)
        assertTrue(headline.layout.getLineBottom(headline.layout.lineCount - 1) <= headline.height)
        assertTrue(body.layout.getLineBottom(body.layout.lineCount - 1) <= body.height)
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
        val view = NativeTemplateLayout(context, NativeTemplate.large1).build(ad(false))
        layout(view, 320, NativeTemplate.large1.height)
        assertNull(view.iconView)
        assertTrue(view.headlineView!!.width >= 280 * context.resources.displayMetrics.density)
        view.destroy()
    }

    @Test fun attributionDoesNotReserveAHeaderAndMetadataFollowsBody() {
        val view = NativeTemplateLayout(context, NativeTemplate.large1).build(ad(true))
        layout(view, 320, NativeTemplate.large1.height)
        fun bounds(asset: View): Rect = Rect(0, 0, asset.width, asset.height).also {
            view.offsetDescendantRectToMyCoords(asset, it)
        }
        val badge = bounds(view.findViewById(R.id.ad_attribution_badge))
        val media = bounds(view.mediaView!!)
        val body = bounds(view.bodyView!!)
        val advertiser = bounds(view.advertiserView!!)
        val rating = bounds(view.starRatingView!!)
        assertEquals((8 * context.resources.displayMetrics.density).toInt(), media.top)
        assertEquals(media.top + (4 * context.resources.displayMetrics.density).toInt(), badge.top)
        assertTrue(media.contains(badge))
        assertTrue(advertiser.top >= body.bottom)
        assertTrue(rating.top >= body.bottom)
        assertFalse(Rect.intersects(badge, advertiser))
        assertNull(view.adChoicesView)
        view.destroy()
    }

    @Test fun absentMetadataCollapsesWithoutAnEmptyFooter() {
        for (template in NativeTemplate.entries) {
            val view = NativeTemplateLayout(context, template).build(ad(false))
            layout(view, 320, template.height)
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
        val cellHeight = (680 * density).toInt()
        val sheet = Bitmap.createBitmap((cardWidth + gutter) * 5 + gutter, cellHeight * 5 + gutter, Bitmap.Config.ARGB_8888)
        val sheetCanvas = Canvas(sheet)
        sheetCanvas.drawColor(0xffeceff1.toInt())
        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.DKGRAY; textSize = 14 * density; typeface = Typeface.DEFAULT_BOLD
        }
        for ((index, template) in NativeTemplate.entries.withIndex()) {
            val fixture = ad(true)
            `when`(fixture.headline).thenReturn("Make room for what matters.")
            `when`(fixture.body).thenReturn("Bring your notes, plans and ideas together in one calm workspace.")
            `when`(fixture.advertiser).thenReturn("Clarity")
            `when`(fixture.callToAction).thenReturn("Get started")
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
                setImageBitmap(creativeFixture())
                scaleType = ImageView.ScaleType.FIT_CENTER
            }, ViewGroup.LayoutParams(-1, -1))
            val height = if (template.isFullscreen) 640 else template.height
            layout(view, 360, height)
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
            File(output, "${template.name}-light.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            val x = gutter + (index % 5) * (cardWidth + gutter)
            val y = gutter + (index / 5) * cellHeight
            sheetCanvas.drawText(template.name, x.toFloat(), y + 16 * density, titlePaint)
            sheetCanvas.drawBitmap(bitmap, x.toFloat(), y + 28 * density, null)
            if (template == NativeTemplate.large1) {
                store.applyStyle("visual", 2, mapOf("card" to NativeStyleData(
                    background = 0xff0f0f0f, headline = 0xfff1f1f1, body = 0xffaaaaaa,
                    callToActionBackground = 0xfff1f1f1, callToActionText = 0xff0f0f0f)))
                val dark = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                view.draw(Canvas(dark))
                File(output, "large1-dark.png").outputStream().use { dark.compress(Bitmap.CompressFormat.PNG, 100, it) }
            }
            view.destroy()
        }
        File(output, "catalog.png").outputStream().use { sheet.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    private fun buildOutput() = System.getProperty("nativeDesignOutput")
        ?: File(System.getProperty("user.dir"), "build/reports").path

    private fun creativeFixture(): Bitmap {
        val bitmap = Bitmap.createBitmap(960, 540, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.shader = LinearGradient(0f, 0f, 960f, 540f, 0xff213f35.toInt(), 0xffc9dfb0.toInt(), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, 960f, 540f, paint)
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
            layout(view, 320, template.height)
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
            for (width in listOf(320, 600)) for (height in listOf(320, 640, 800)) {
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
                    NativeTemplate.fullscreen1, NativeTemplate.fullscreen3 -> assertTrue(media.bottom <= headline.top && headline.bottom <= button.top)
                    NativeTemplate.fullscreen4 -> assertTrue(media.bottom <= headline.top && media.bottom <= button.top)
                    NativeTemplate.fullscreen2 -> assertTrue(headline.bottom <= media.top && media.bottom <= button.top)
                    NativeTemplate.fullscreen5 -> assertTrue(headline.bottom <= button.top && button.bottom <= media.top)
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

    @Test fun colorsResetAndStaleRevisionsCannotRepaintLiveViews() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        store.applyStyle("session", 1, mapOf("render" to NativeStyleData(headline = 0xff00ff00)))
        val view = NativeTemplateFactory(context, NativeTemplate.small1, store).createNativeAd(
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
            layout(view, 320, template.height)
            val cta = view.callToActionView!!
            val size = cta.width to cta.height
            val original = (cta.background as GradientDrawable).cornerRadius
            val badge = view.findViewById<View>(R.id.ad_attribution_badge)
            val badgeRadius = (badge.background as GradientDrawable).cornerRadius
            for ((index, radius) in listOf(0.0, 6.5, Double.MAX_VALUE, null).withIndex()) {
                store.applyStyle("shape", (index + 2).toLong(), mapOf("render" to NativeStyleData(
                    callToActionCornerRadius = radius, callToActionBackground = 0xff00ff00)))
                layout(view, 320, template.height)
                val expected = radius?.let { (it * context.resources.displayMetrics.density).toFloat().coerceAtMost(original) } ?: original
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
            layout(view, 320, template.height)
            val card = view.findViewById<View>(R.id.ad_card_container)
            val cta = view.callToActionView!!
            val cardRadius = (card.background as GradientDrawable).cornerRadius
            val ctaRadius = (cta.background as GradientDrawable).cornerRadius
            val bounds = listOf(card, cta).map { Rect(it.left, it.top, it.right, it.bottom) }
            assertEquals(16f * density, cardRadius, template.name)
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
                layout(view, 320, template.height)
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
        val view = NativeTemplateFactory(context, NativeTemplate.small1, store).createNativeAd(ad(true),
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
