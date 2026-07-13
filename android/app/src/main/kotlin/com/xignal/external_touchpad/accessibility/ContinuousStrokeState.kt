package com.xignal.external_touchpad.accessibility

internal data class ContinueStrokeRequest(
    val startX: Float,
    val startY: Float,
    val endX: Float,
    val endY: Float,
    val startTimeMs: Long,
    val durationMs: Long,
    val willContinue: Boolean,
)

/** Pure state used to construct an ordered continueStroke chain. */
internal class ContinuousStrokeState(startX: Float, startY: Float) {
    var currentX: Float = startX
        private set
    var currentY: Float = startY
        private set

    fun next(
        targetX: Float,
        targetY: Float,
        durationMs: Long,
        willContinue: Boolean,
    ): ContinueStrokeRequest {
        val request = ContinueStrokeRequest(
            startX = currentX,
            startY = currentY,
            endX = targetX,
            endY = targetY,
            startTimeMs = 0L,
            durationMs = durationMs,
            willContinue = willContinue,
        )
        currentX = targetX
        currentY = targetY
        return request
    }
}
