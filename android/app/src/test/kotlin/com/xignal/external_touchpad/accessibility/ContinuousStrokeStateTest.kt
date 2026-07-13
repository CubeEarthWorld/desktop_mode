package com.xignal.external_touchpad.accessibility

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ContinuousStrokeStateTest {
    @Test
    fun `each segment starts at the previous endpoint with startTime zero`() {
        val state = ContinuousStrokeState(100f, 200f)

        val first = state.next(120f, 230f, durationMs = 16L, willContinue = true)
        val second = state.next(140f, 260f, durationMs = 20L, willContinue = true)

        assertEquals(100f, first.startX)
        assertEquals(200f, first.startY)
        assertEquals(0L, first.startTimeMs)
        assertEquals(first.endX, second.startX)
        assertEquals(first.endY, second.startY)
        assertEquals(0L, second.startTimeMs)
        assertTrue(first.willContinue)
        assertTrue(second.willContinue)
    }

    @Test
    fun `final segment releases instead of continuing`() {
        val state = ContinuousStrokeState(10f, 20f)
        state.next(30f, 40f, durationMs = 16L, willContinue = true)

        val final = state.next(30f, 40f, durationMs = 1L, willContinue = false)

        assertEquals(30f, final.startX)
        assertEquals(40f, final.startY)
        assertEquals(30f, final.endX)
        assertEquals(40f, final.endY)
        assertFalse(final.willContinue)
    }
}
