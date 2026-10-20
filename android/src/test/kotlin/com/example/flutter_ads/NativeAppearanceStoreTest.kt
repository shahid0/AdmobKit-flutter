package com.example.flutter_ads

import kotlin.test.Test
import kotlin.test.assertFailsWith

internal class NativeAppearanceStoreTest {
    @Test
    fun staleSessionCannotPaintOrEndNewSession() {
        val store = NativeAppearanceStore()
        store.startSession("old")
        store.startSession("new")
        assertFailsWith<IllegalStateException> { store.applyStyle("old", 9, emptyMap()) }
        store.endSession("old")
        store.applyStyle("new", 1, emptyMap())
        store.endSession("new")
        assertFailsWith<IllegalStateException> { store.applyStyle("new", 2, emptyMap()) }
    }

    @Test
    fun engineDetachInvalidatesAppearance() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        store.clear()
        assertFailsWith<IllegalStateException> { store.applyStyle("session", 1, emptyMap()) }
        store.startSession("next")
        store.applyStyle("next", 1, emptyMap())
    }

    @Test
    fun malformedRadiusDoesNotAdvanceRevision() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        for (radius in listOf(-1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertFailsWith<IllegalArgumentException> {
                store.applyStyle("session", 2, mapOf("render" to NativeStyleData(callToActionCornerRadius = radius)))
            }
        }
        store.applyStyle("session", 2, mapOf("render" to NativeStyleData(callToActionCornerRadius = 0.0)))
    }
}
