package com.xignal.external_touchpad.navigation

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import com.xignal.external_touchpad.accessibility.GestureAck
import com.xignal.external_touchpad.accessibility.GestureInjector

private const val TAG = "ExternalDisplayNavigator"
private const val HOME_LAUNCH_COOLDOWN_MS = 1500L
private const val MAX_NAV_NODE_SCAN = 512
private const val MAX_NAV_PARENT_DEPTH = 4

/**
 * Performs display-scoped system navigation.
 *
 * The HOME launcher is injected as a function so this class depends on behavior rather than the
 * concrete app-launch implementation.
 */
class ExternalDisplayNavigator(
    private val gestureInjector: GestureInjector,
    private val launchHome: (displayId: Int) -> Boolean,
    private val onGestureOutcome: (outcome: String) -> Unit,
    private val elapsedRealtime: () -> Long = SystemClock::elapsedRealtime,
) {
    private var lastHomeLaunchAtMs = 0L

    fun markHomeLaunched() {
        lastHomeLaunchAtMs = elapsedRealtime()
    }

    fun perform(
        service: AccessibilityService,
        displayId: Int,
        action: String,
        width: Float,
        height: Float,
    ): Boolean {
        if (action == "home") {
            return performHome(service, displayId, width, height)
        }
        if (action == "back") {
            val method = activateNavigationBack(service, displayId, width, height)
            if (method != null) {
                Log.d(TAG, "action=back display=$displayId method=$method")
                return true
            }
        }

        val accepted = injectNavigationGesture(service, displayId, action, width, height)
        Log.d(TAG, "action=$action display=$displayId gestureAccepted=$accepted")
        return accepted
    }

    private fun performHome(
        service: AccessibilityService,
        displayId: Int,
        width: Float,
        height: Float,
    ): Boolean {
        val now = elapsedRealtime()
        if (now - lastHomeLaunchAtMs < HOME_LAUNCH_COOLDOWN_MS) {
            Log.d(TAG, "action=home display=$displayId ignored=cooldown")
            return true
        }
        lastHomeLaunchAtMs = now
        if (launchHome(displayId)) {
            Log.d(TAG, "action=home display=$displayId launchedHome=true")
            return true
        }
        val accepted = injectNavigationGesture(service, displayId, "home", width, height)
        Log.d(TAG, "action=home display=$displayId fallbackGestureAccepted=$accepted")
        return accepted
    }

    private fun activateNavigationBack(
        service: AccessibilityService,
        displayId: Int,
        displayWidth: Float,
        displayHeight: Float,
    ): String? {
        val windows = service.windowsOnAllDisplays[displayId] ?: return null
        val systemBackLabel = service.systemActions
            .firstOrNull { it.id == AccessibilityService.GLOBAL_ACTION_BACK }
            ?.label
        for (window in windows.sortedByDescending { it.layer }) {
            if (window.type != AccessibilityWindowInfo.TYPE_SYSTEM) continue
            val root = window.root ?: continue
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            var visited = 0
            while (queue.isNotEmpty() && visited++ < MAX_NAV_NODE_SCAN) {
                val node = queue.removeFirst()
                if (BackNavigationNodeMatcher.matches(
                        viewIdResourceName = node.viewIdResourceName,
                        contentDescription = node.contentDescription,
                        text = node.text,
                        systemBackLabel = systemBackLabel,
                    )
                ) {
                    activateNode(node)?.let { return it }
                    if (tapNode(service, displayId, node, displayWidth, displayHeight)) {
                        return "nav_button_tap"
                    }
                }
                for (index in 0 until node.childCount) {
                    node.getChild(index)?.let(queue::addLast)
                }
            }
        }
        return null
    }

    private fun activateNode(node: AccessibilityNodeInfo): String? {
        var candidate: AccessibilityNodeInfo? = node
        repeat(MAX_NAV_PARENT_DEPTH) {
            val current = candidate ?: return null
            val supportsClick = current.isClickable || current.actionList.any {
                it.id == AccessibilityNodeInfo.ACTION_CLICK
            }
            if (supportsClick && current.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return "nav_button_action"
            }
            candidate = current.parent
        }
        return null
    }

    private fun tapNode(
        service: AccessibilityService,
        displayId: Int,
        node: AccessibilityNodeInfo,
        displayWidth: Float,
        displayHeight: Float,
    ): Boolean {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (bounds.isEmpty) return false
        val x = bounds.exactCenterX()
        val y = bounds.exactCenterY()
        if (x < 0f || x >= displayWidth || y < 0f || y >= displayHeight) return false
        return gestureInjector.tap(
            service = service,
            displayId = displayId,
            x = x,
            y = y,
            durationMs = NAV_BUTTON_TAP_DURATION_MS,
            onOutcome = onGestureOutcome,
            onFinished = {},
        ) == GestureAck.ACCEPTED
    }

    private fun injectNavigationGesture(
        service: AccessibilityService,
        displayId: Int,
        action: String,
        width: Float,
        height: Float,
    ): Boolean {
        fun injectSwipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long,
        ): Boolean = gestureInjector.swipe(
            service,
            displayId,
            startX,
            startY,
            endX,
            endY,
            durationMs,
            onGestureOutcome,
        )

        return when (action) {
            "back" -> injectSwipe(2f, height * 0.5f, width * 0.18f, height * 0.5f, 180L)
            "home" ->
                injectSwipe(width * 0.5f, height - 2f, width * 0.5f, height * 0.68f, 260L)
            else -> false
        }
    }

    private companion object {
        const val NAV_BUTTON_TAP_DURATION_MS = 40L
    }
}
