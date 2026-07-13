package com.xignal.external_touchpad.accessibility

import org.junit.Assert.assertEquals
import org.junit.Test

class SoftKeyboardPolicyTest {
    @Test
    fun inactiveSessionUsesSystemPolicy() {
        assertEquals(
            SoftKeyboardPolicy.SYSTEM,
            resolveSoftKeyboardPolicy(
                externalSessionActive = false,
                dismissedByTouchpad = true,
                hasHardwareKeyboard = false,
            ),
        )
    }

    @Test
    fun touchpadDismissalKeepsImeHidden() {
        assertEquals(
            SoftKeyboardPolicy.HIDDEN,
            resolveSoftKeyboardPolicy(
                externalSessionActive = true,
                dismissedByTouchpad = true,
                hasHardwareKeyboard = false,
            ),
        )
    }

    @Test
    fun hardwareKeyboardUsesSystemPolicy() {
        assertEquals(
            SoftKeyboardPolicy.SYSTEM,
            resolveSoftKeyboardPolicy(
                externalSessionActive = true,
                dismissedByTouchpad = false,
                hasHardwareKeyboard = true,
            ),
        )
    }

    @Test
    fun sessionWithoutHardwareKeyboardForcesSoftImeAvailable() {
        assertEquals(
            SoftKeyboardPolicy.FORCE_SOFT,
            resolveSoftKeyboardPolicy(
                externalSessionActive = true,
                dismissedByTouchpad = false,
                hasHardwareKeyboard = false,
            ),
        )
    }
}
