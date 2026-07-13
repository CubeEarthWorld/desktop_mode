package com.xignal.external_touchpad.navigation

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BackNavigationNodeMatcherTest {
    @Test
    fun `matches common SystemUI back resource IDs`() {
        assertTrue(matches(viewId = "com.android.systemui:id/back"))
        assertTrue(matches(viewId = "com.vivo.systemui:id/back_button"))
        assertTrue(matches(viewId = "com.vivo.systemui:id/navigation_back"))
        assertTrue(matches(viewId = "com.vivo.systemui:id/back_key"))
    }

    @Test
    fun `does not mistake a background resource for Back`() {
        assertFalse(matches(viewId = "com.android.systemui:id/navigation_bar_background"))
        assertFalse(matches(description = "Background", systemLabel = "Back"))
    }

    @Test
    fun `matches the localized system action label`() {
        assertTrue(matches(description = "戻るボタン", systemLabel = "戻る"))
        assertTrue(matches(description = "Zurück", systemLabel = "Zurück"))
        assertTrue(matches(text = "Go back", systemLabel = "Back"))
    }

    @Test
    fun `does not match unrelated navigation controls`() {
        assertFalse(matches(description = "ホーム", systemLabel = "戻る"))
        assertFalse(matches(description = "Recent apps", systemLabel = "Back"))
    }

    private fun matches(
        viewId: String? = null,
        description: String? = null,
        text: String? = null,
        systemLabel: String? = null,
    ): Boolean = BackNavigationNodeMatcher.matches(
        viewIdResourceName = viewId,
        contentDescription = description,
        text = text,
        systemBackLabel = systemLabel,
    )
}
