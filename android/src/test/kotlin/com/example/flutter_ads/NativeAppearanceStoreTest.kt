package com.example.flutter_ads

import kotlin.test.Test
import kotlin.test.assertFailsWith

internal class NativeAppearanceStoreTest {
    @Test
    fun staleSessionCannotPaintOrEndNewSession() {
        val store = NativeAppearanceStore()
        store.startSession("old")
        store.startSession("new")
        assertFailsWith<IllegalStateException> { store.applyColors("old", 9, emptyMap()) }
        store.endSession("old")
        store.applyColors("new", 1, emptyMap())
        store.endSession("new")
        assertFailsWith<IllegalStateException> { store.applyColors("new", 2, emptyMap()) }
    }

    @Test
    fun engineDetachInvalidatesAppearance() {
        val store = NativeAppearanceStore()
        store.startSession("session")
        store.clear()
        assertFailsWith<IllegalStateException> { store.applyColors("session", 1, emptyMap()) }
        store.startSession("next")
        store.applyColors("next", 1, emptyMap())
    }
}
