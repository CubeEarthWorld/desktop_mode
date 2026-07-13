package com.xignal.external_touchpad.apps

import android.accessibilityservice.AccessibilityService
import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Rect
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import com.xignal.external_touchpad.display.DisplaySessionManager
import kotlin.math.abs
import kotlin.math.roundToInt

private const val TAG = "ExternalAppLauncher"

private data class ExpectedLaunchBounds(
    val packageName: String?,
    val displayId: Int,
    val bounds: Rect,
)

/**
 * Launches HOME and regular applications on a target display.
 *
 * All launch-intent construction, aspect-ratio policy, and post-launch verification live here,
 * leaving the top-level controller responsible only for session orchestration.
 */
class ExternalAppLauncher(
    context: Context,
    private val displays: DisplaySessionManager,
    private val appCatalog: AppCatalog,
    private val onLaunchFailure: (message: String) -> Unit,
    private val onWarning: (code: String, message: String) -> Unit,
) {
    private val appContext = context.applicationContext

    private var externalHomePackage: String? = null
    private var externalHomeActivity: String? = null
    private var appWindowModes: Map<String, String> = emptyMap()
    private var pendingLaunchVerification: ExpectedLaunchBounds? = null

    var launchBoundsWarning: String? = null
        private set

    fun updateConfig(
        externalHomePackage: String?,
        externalHomeActivity: String?,
        appWindowModes: Map<String, String>,
    ) {
        this.externalHomePackage = externalHomePackage
        this.externalHomeActivity = externalHomeActivity
        this.appWindowModes = appWindowModes
    }

    fun clearPendingVerification() {
        pendingLaunchVerification = null
    }

    fun onAccessibilityEvent(
        event: AccessibilityEvent,
        service: AccessibilityService,
    ) {
        val expected = pendingLaunchVerification ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }
        val eventPackage = event.packageName?.toString()
        if (expected.packageName != null &&
            eventPackage != null &&
            eventPackage != expected.packageName
        ) {
            return
        }
        val windows = service.windowsOnAllDisplays[expected.displayId] ?: return
        val window = windows.firstOrNull { candidate ->
            candidate.type == AccessibilityWindowInfo.TYPE_APPLICATION &&
                (expected.packageName == null ||
                    candidate.root?.packageName?.toString() == expected.packageName)
        } ?: return
        val actual = Rect()
        window.getBoundsInScreen(actual)
        pendingLaunchVerification = null
        if (actual.width() <= 0 || actual.height() <= 0) return

        val expectedAspect = expected.bounds.width().toFloat() / expected.bounds.height()
        val actualAspect = actual.width().toFloat() / actual.height()
        if (abs(actualAspect / expectedAspect - 1f) > 0.05f) {
            recordWarning(
                "launch_bounds_ignored",
                "Requested ${expected.bounds.width()}x${expected.bounds.height()}, " +
                    "but received ${actual.width()}x${actual.height()}",
            )
        } else {
            launchBoundsWarning = null
        }
    }

    fun launchHome(displayId: Int): Boolean {
        val display = displays.findDisplay(displayId) ?: return false

        val overridePackage = externalHomePackage
        val overrideActivity = externalHomeActivity
        if (overridePackage != null && overrideActivity != null) {
            val info = appCatalog.resolveActivityInfo(overridePackage, overrideActivity)
            val bounds = computeLaunchBounds(display, info)
            val launched = launchIntentOnDisplay(displayId, bounds) {
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .setClassName(overridePackage, overrideActivity)
            }
            if (launched) return true
            Log.w(
                TAG,
                "Configured home app $overridePackage/$overrideActivity failed; using default",
            )
        }

        val baseIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val activityInfo = appContext.packageManager
            .resolveActivity(baseIntent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo
            ?: return false
        val bounds = computeLaunchBounds(display, activityInfo)
        return launchIntentOnDisplay(displayId, bounds) {
            Intent(baseIntent).setClassName(activityInfo.packageName, activityInfo.name)
        }
    }

    fun launchApp(
        display: Display,
        packageName: String,
        activityName: String,
    ): Boolean {
        val info = appCatalog.resolveActivityInfo(packageName, activityName)
        val bounds = computeLaunchBounds(display, info)
        return launchIntentOnDisplay(display.displayId, bounds) {
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_NEW_DOCUMENT or
                        Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                        Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
                )
                .setClassName(packageName, activityName)
        }
    }

    private fun computeLaunchBounds(display: Display, info: ActivityInfo?): Rect? {
        launchBoundsWarning = null
        val componentKey = info?.let { "${it.packageName}/${it.name}" }
        val configuredMode = componentKey?.let { appWindowModes[it] } ?: "auto"
        val orientation = info?.screenOrientation ?: ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        val resolvedMode = when (configuredMode) {
            "phonePortrait" -> "phonePortrait"
            "phoneLandscape" -> "phoneLandscape"
            "fullExternal" -> "fullExternal"
            else -> when {
                isEffectivelyPortrait(orientation) -> "phonePortrait"
                isEffectivelyLandscape(orientation) -> "phoneLandscape"
                else -> "fullExternal"
            }
        }
        if (resolvedMode == "fullExternal") return null
        if (!supportsLaunchBounds()) {
            launchBoundsWarning =
                "launch_bounds_capability_unreported: requesting phone aspect ratio anyway"
        }

        val defaultDisplay = displays.findDisplay(Display.DEFAULT_DISPLAY) ?: return null
        val phone = displays.usableBounds(defaultDisplay)
        val target = displays.usableBounds(display)
        if (phone.width() <= 0 || phone.height() <= 0 ||
            target.width() <= 0 || target.height() <= 0
        ) {
            return null
        }

        val shortSide = minOf(phone.width(), phone.height()).toFloat()
        val longSide = maxOf(phone.width(), phone.height()).toFloat()
        val desiredAspect = if (resolvedMode == "phonePortrait") {
            shortSide / longSide
        } else {
            longSide / shortSide
        }
        val targetAspect = target.width().toFloat() / target.height()
        val width: Int
        val height: Int
        if (targetAspect > desiredAspect) {
            height = target.height()
            width = (height * desiredAspect).roundToInt().coerceAtLeast(1)
        } else {
            width = target.width()
            height = (width / desiredAspect).roundToInt().coerceAtLeast(1)
        }
        val left = target.left + (target.width() - width) / 2
        val top = target.top + (target.height() - height) / 2
        return Rect(left, top, left + width, top + height)
    }

    private fun supportsLaunchBounds(): Boolean =
        appContext.packageManager.hasSystemFeature(
            PackageManager.FEATURE_FREEFORM_WINDOW_MANAGEMENT,
        )

    private fun recordWarning(code: String, message: String) {
        launchBoundsWarning = "$code: $message"
        onWarning(code, message)
    }

    private fun isEffectivelyPortrait(orientation: Int): Boolean =
        orientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT

    private fun isEffectivelyLandscape(orientation: Int): Boolean =
        orientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE

    private fun launchIntentOnDisplay(
        displayId: Int,
        bounds: Rect?,
        buildIntent: () -> Intent?,
    ): Boolean {
        val launchIntent = buildIntent() ?: return false
        val display = displays.findDisplay(displayId)
            ?: return false.also {
                Log.w(TAG, "Cannot find display $displayId for app launch")
            }
        val displayContext = appContext.createDisplayContext(display)
        val options = ActivityOptions.makeBasic().setLaunchDisplayId(displayId)
        if (bounds != null) {
            options.setLaunchBounds(bounds)
            pendingLaunchVerification = ExpectedLaunchBounds(
                packageName = launchIntent.component?.packageName,
                displayId = displayId,
                bounds = Rect(bounds),
            )
        } else {
            pendingLaunchVerification = null
        }

        return try {
            displayContext.startActivity(launchIntent, options.toBundle())
            true
        } catch (error: Exception) {
            onLaunchFailure("home_launch_failed: ${error.message}")
            Log.w(TAG, "Unable to launch app on display $displayId", error)
            false
        }
    }
}
