package com.xignal.external_touchpad.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log

private const val TAG = "GestureInjector"

enum class GestureAck(val wireName: String) {
    ACCEPTED("accepted"),
    QUEUED("queued"),
    ALREADY_ENDED("alreadyEnded"),
    STALE("stale"),
    CANCELLED("cancelled"),
    FAILED("failed"),
}

enum class ContinuousGestureKind(val wireName: String) {
    DRAG("drag"),
    SCROLL("scroll");

    companion object {
        fun fromWireName(value: String): ContinuousGestureKind? = entries.firstOrNull {
            it.wireName == value
        }
    }
}

/**
 * Serializes Accessibility gesture dispatch and keeps a continuous pointer
 * down by deriving every segment from StrokeDescription.continueStroke().
 */
class GestureInjector {
    var lastGestureResult: String = "none"
        private set
    var lastCancellationReason: String? = null
        private set

    val activeGestureId: Long?
        get() = continuous?.id
    val activeGestureKind: String?
        get() = continuous?.kind?.wireName

    private class SingleShotSession(
        val onOutcome: (String) -> Unit,
        val onFinished: (GestureAck) -> Unit,
    ) {
        var timeoutRunnable: Runnable? = null
    }

    private var singleShot: SingleShotSession? = null
    private var continuous: ContinuousSession? = null
    private var lastTerminatedId: Long = 0L
    private val callbackHandler = Handler(Looper.getMainLooper())

    private class ContinuousSession(
        val id: Long,
        val kind: ContinuousGestureKind,
        val service: AccessibilityService,
        val displayId: Int,
        var stroke: GestureDescription.StrokeDescription,
        currentX: Float,
        currentY: Float,
        var targetX: Float,
        var targetY: Float,
        val onOutcome: (String) -> Unit,
    ) {
        var inFlight: Boolean = true
        var endRequested: Boolean = false
        var cancelledByClient: Boolean = false
        var finalSegment: Boolean = false
        var lastDispatchAtMs: Long = SystemClock.uptimeMillis()
        val endCallbacks = mutableListOf<(GestureAck) -> Unit>()
        val strokeState = ContinuousStrokeState(currentX, currentY)
        var timeoutRunnable: Runnable? = null
    }

    fun tap(
        service: AccessibilityService,
        displayId: Int,
        x: Float,
        y: Float,
        durationMs: Long,
        onOutcome: (String) -> Unit,
        onFinished: (GestureAck) -> Unit,
    ): GestureAck = dispatchSingleShot(
        service = service,
        displayId = displayId,
        strokes = listOf(
            GestureDescription.StrokeDescription(
                stationaryPath(x, y),
                0,
                durationMs.coerceAtLeast(MIN_DURATION_MS),
            ),
        ),
        onOutcome = onOutcome,
        onFinished = onFinished,
    )

    fun swipe(
        service: AccessibilityService,
        displayId: Int,
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long,
        onOutcome: (String) -> Unit,
    ): Boolean {
        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        return dispatchSingleShot(
            service = service,
            displayId = displayId,
            strokes = listOf(
                GestureDescription.StrokeDescription(
                    path,
                    0,
                    durationMs.coerceAtLeast(MIN_DURATION_MS),
                ),
            ),
            onOutcome = onOutcome,
            onFinished = {},
        ) == GestureAck.ACCEPTED
    }

    fun beginContinuous(
        service: AccessibilityService,
        displayId: Int,
        id: Long,
        kind: ContinuousGestureKind,
        x: Float,
        y: Float,
        onOutcome: (String) -> Unit,
    ): GestureAck {
        if (continuous != null || singleShot != null) {
            lastGestureResult = "busy"
            return GestureAck.FAILED
        }
        if (id <= lastTerminatedId) return GestureAck.STALE

        val stroke = GestureDescription.StrokeDescription(
            stationaryPath(x, y),
            0,
            CONTACT_DURATION_MS,
            true,
        )
        val session = ContinuousSession(
            id = id,
            kind = kind,
            service = service,
            displayId = displayId,
            stroke = stroke,
            currentX = x,
            currentY = y,
            targetX = x,
            targetY = y,
            onOutcome = onOutcome,
        )
        continuous = session
        val accepted = dispatchContinuousSegment(session, stroke)
        if (!accepted) {
            terminate(session, GestureAck.FAILED, "initial_dispatch_rejected")
            return GestureAck.FAILED
        }
        lastGestureResult = "continuous_started"
        return GestureAck.ACCEPTED
    }

    fun updateContinuous(id: Long, x: Float, y: Float): GestureAck {
        val session = continuous
        if (session == null) {
            return if (id <= lastTerminatedId) GestureAck.ALREADY_ENDED else GestureAck.STALE
        }
        if (session.id != id || session.endRequested) return GestureAck.STALE
        session.targetX = x
        session.targetY = y
        if (!session.inFlight) pump(session)
        return GestureAck.QUEUED
    }

    fun endContinuous(
        id: Long,
        cancelled: Boolean,
        onFinished: (GestureAck) -> Unit,
    ) {
        val session = continuous
        if (session == null) {
            onFinished(if (id <= lastTerminatedId) GestureAck.ALREADY_ENDED else GestureAck.STALE)
            return
        }
        if (session.id != id) {
            onFinished(GestureAck.STALE)
            return
        }
        session.endCallbacks += onFinished
        session.endRequested = true
        session.cancelledByClient = session.cancelledByClient || cancelled
        if (!session.inFlight) pump(session)
    }

    /** Clears state, or best-effort releases a continued pointer first. */
    fun reset(reason: String = "reset", releasePointer: Boolean = false) {
        singleShot?.let { session ->
            cancelSingleShotWatchdog(session)
            session.onFinished(GestureAck.CANCELLED)
        }
        singleShot = null
        val session = continuous
        if (session != null && releasePointer) {
            lastCancellationReason = reason
            session.endRequested = true
            session.cancelledByClient = true
            if (!session.inFlight) pump(session)
            return
        }
        session?.let {
            lastTerminatedId = maxOf(lastTerminatedId, it.id)
            it.endCallbacks.forEach { callback -> callback(GestureAck.CANCELLED) }
        }
        continuous = null
        lastGestureResult = "reset"
        lastCancellationReason = reason
    }

    private fun pump(session: ContinuousSession) {
        if (continuous !== session || session.inFlight) return

        val hasMove = session.targetX != session.strokeState.currentX ||
            session.targetY != session.strokeState.currentY
        if (!hasMove && !session.endRequested) return

        val willContinue = !session.endRequested
        val duration = if (hasMove) segmentDuration(session) else RELEASE_DURATION_MS
        val request = session.strokeState.next(
            targetX = session.targetX,
            targetY = session.targetY,
            durationMs = duration,
            willContinue = willContinue,
        )
        val path = Path().apply {
            moveTo(request.startX, request.startY)
            lineTo(request.endX, request.endY)
        }
        val continuation = try {
            session.stroke.continueStroke(
                path,
                request.startTimeMs,
                request.durationMs,
                request.willContinue,
            )
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "Unable to continue gesture ${session.id}", error)
            terminate(session, GestureAck.FAILED, "continue_stroke_invalid")
            return
        }

        session.stroke = continuation
        session.finalSegment = !willContinue
        session.inFlight = true
        session.lastDispatchAtMs = SystemClock.uptimeMillis()
        if (!dispatchContinuousSegment(session, continuation)) {
            terminate(session, GestureAck.FAILED, "continuation_dispatch_rejected")
        }
    }

    private fun dispatchContinuousSegment(
        session: ContinuousSession,
        stroke: GestureDescription.StrokeDescription,
    ): Boolean {
        val gesture = GestureDescription.Builder()
            .setDisplayId(session.displayId)
            .addStroke(stroke)
            .build()
        val accepted = session.service.dispatchGesture(
            gesture,
            object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    if (continuous !== session) return
                    cancelContinuousWatchdog(session)
                    session.inFlight = false
                    if (session.finalSegment) {
                        val ack = if (session.cancelledByClient) {
                            GestureAck.CANCELLED
                        } else {
                            GestureAck.ACCEPTED
                        }
                        terminate(session, ack, null)
                    } else {
                        lastGestureResult = "continuous_segment_completed"
                        pump(session)
                    }
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    if (continuous !== session) return
                    cancelContinuousWatchdog(session)
                    terminate(session, GestureAck.CANCELLED, "system_cancelled")
                    session.onOutcome("cancelled")
                }
            },
            null,
        )
        if (accepted && continuous === session) {
            armContinuousWatchdog(session)
        }
        return accepted
    }

    private fun terminate(
        session: ContinuousSession,
        ack: GestureAck,
        reason: String?,
    ) {
        if (continuous !== session) return
        cancelContinuousWatchdog(session)
        continuous = null
        lastTerminatedId = maxOf(lastTerminatedId, session.id)
        lastGestureResult = when (ack) {
            GestureAck.ACCEPTED -> "completed"
            GestureAck.CANCELLED -> "cancelled"
            else -> "failed"
        }
        lastCancellationReason = reason
        val callbacks = session.endCallbacks.toList()
        session.endCallbacks.clear()
        callbacks.forEach { it(ack) }
    }

    private fun dispatchSingleShot(
        service: AccessibilityService,
        displayId: Int,
        strokes: List<GestureDescription.StrokeDescription>,
        onOutcome: (String) -> Unit,
        onFinished: (GestureAck) -> Unit,
    ): GestureAck {
        if (continuous != null || singleShot != null) {
            lastGestureResult = "busy"
            return GestureAck.FAILED
        }
        val singleShotSession = SingleShotSession(onOutcome, onFinished)
        singleShot = singleShotSession
        val builder = GestureDescription.Builder().setDisplayId(displayId)
        strokes.forEach { builder.addStroke(it) }
        val accepted = service.dispatchGesture(
            builder.build(),
            object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    if (singleShot !== singleShotSession) return
                    cancelSingleShotWatchdog(singleShotSession)
                    singleShot = null
                    lastGestureResult = "completed"
                    onOutcome("completed")
                    onFinished(GestureAck.ACCEPTED)
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    if (singleShot !== singleShotSession) return
                    cancelSingleShotWatchdog(singleShotSession)
                    singleShot = null
                    lastGestureResult = "cancelled"
                    lastCancellationReason = "system_cancelled"
                    onOutcome("cancelled")
                    onFinished(GestureAck.CANCELLED)
                }
            },
            null,
        )
        if (!accepted) {
            singleShot = null
            lastGestureResult = "dispatch_failed"
            return GestureAck.FAILED
        }
        val gestureDurationMs = strokes.maxOfOrNull { it.duration } ?: MIN_DURATION_MS
        armSingleShotWatchdog(singleShotSession, gestureDurationMs)
        return GestureAck.ACCEPTED
    }

    /**
     * A few OEM accessibility implementations occasionally accept a gesture
     * without ever invoking its result callback. Without a watchdog, the
     * injector remains busy forever and every later two-finger gesture is
     * rejected. Clearing the stale session also lets the next dispatch cancel
     * any pointer that the system may still consider down.
     */
    private fun armContinuousWatchdog(session: ContinuousSession) {
        cancelContinuousWatchdog(session)
        val timeout = Runnable {
            if (continuous !== session) return@Runnable
            Log.w(TAG, "Gesture ${session.id} callback timed out")
            session.inFlight = false
            terminate(session, GestureAck.FAILED, "callback_timeout")
            session.onOutcome("cancelled")
        }
        session.timeoutRunnable = timeout
        callbackHandler.postDelayed(timeout, CONTINUOUS_CALLBACK_TIMEOUT_MS)
    }

    private fun cancelContinuousWatchdog(session: ContinuousSession) {
        session.timeoutRunnable?.let(callbackHandler::removeCallbacks)
        session.timeoutRunnable = null
    }

    private fun armSingleShotWatchdog(session: SingleShotSession, gestureDurationMs: Long) {
        cancelSingleShotWatchdog(session)
        val timeout = Runnable {
            if (singleShot !== session) return@Runnable
            Log.w(TAG, "Single-shot gesture callback timed out")
            singleShot = null
            lastGestureResult = "failed"
            lastCancellationReason = "callback_timeout"
            session.onOutcome("cancelled")
            session.onFinished(GestureAck.FAILED)
        }
        session.timeoutRunnable = timeout
        callbackHandler.postDelayed(timeout, gestureDurationMs + CALLBACK_TIMEOUT_GRACE_MS)
    }

    private fun cancelSingleShotWatchdog(session: SingleShotSession) {
        session.timeoutRunnable?.let(callbackHandler::removeCallbacks)
        session.timeoutRunnable = null
    }

    private fun segmentDuration(session: ContinuousSession): Long =
        (SystemClock.uptimeMillis() - session.lastDispatchAtMs)
            .coerceIn(MIN_SEGMENT_DURATION_MS, MAX_SEGMENT_DURATION_MS)

    private fun stationaryPath(x: Float, y: Float): Path = Path().apply {
        moveTo(x, y)
        lineTo(x, y)
    }

    private companion object {
        const val MIN_DURATION_MS = 1L
        const val CONTACT_DURATION_MS = 16L
        const val RELEASE_DURATION_MS = 1L
        const val MIN_SEGMENT_DURATION_MS = 8L
        const val MAX_SEGMENT_DURATION_MS = 50L
        const val CALLBACK_TIMEOUT_GRACE_MS = 1_000L
        const val CONTINUOUS_CALLBACK_TIMEOUT_MS = 1_500L
    }
}
