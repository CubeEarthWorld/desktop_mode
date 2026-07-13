package com.xignal.external_touchpad.platform

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.xignal.external_touchpad.ExternalTouchpadController
import com.xignal.external_touchpad.ExternalTouchpadException
import com.xignal.external_touchpad.accessibility.ContinuousGestureKind
import com.xignal.external_touchpad.service.DisplayMonitorService
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * MethodChannel/EventChannel の終端。引数の取り出しと Map への変換、
 * `ExternalTouchpadController` へのルーティングのみを行い、ロジックは一切持たない(SRP)。
 */
class ExternalTouchpadChannel(
    private val context: Context,
    private val controller: ExternalTouchpadController,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val appListExecutor = Executors.newFixedThreadPool(2)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getDisplays" ->
                    result.success(controller.getDisplays().map { it.toMap() })

                "getSupportedDisplayModes" -> {
                    val displayId = call.argument<Int>("displayId") ?: -1
                    result.success(controller.getSupportedDisplayModes(displayId).map { it.toMap() })
                }

                "getSessionState" ->
                    result.success(controller.getSessionState().toMap())

                "startSession" -> {
                    val displayId = call.argument<Int>("displayId")
                    result.success(controller.startSession(displayId).toMap())
                }

                "stopSession" -> {
                    controller.stopSession()
                    result.success(null)
                }

                "dismissSoftKeyboard" -> {
                    controller.dismissSoftKeyboard()
                    result.success(null)
                }

                "moveCursor" -> {
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    controller.moveCursor(dx, dy)
                    result.success(null)
                }

                "commitPointerAction" -> {
                    val type = call.argument<String>("type") ?: ""
                    val showFeedback = call.argument<Boolean>("showFeedback") ?: false
                    controller.commitPointerAction(type, showFeedback) { ack ->
                        result.success(ack.wireName)
                    }
                }

                "beginContinuousGesture" -> {
                    val id = (call.argument<Number>("id") ?: 0).toLong()
                    val kind = ContinuousGestureKind.fromWireName(
                        call.argument<String>("kind") ?: "",
                    )
                    if (kind == null) {
                        result.success("failed")
                    } else {
                        result.success(controller.beginContinuousGesture(id, kind).wireName)
                    }
                }

                "updateContinuousGesture" -> {
                    val id = (call.argument<Number>("id") ?: 0).toLong()
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    result.success(controller.updateContinuousGesture(id, dx, dy).wireName)
                }

                "endContinuousGesture" -> {
                    val id = (call.argument<Number>("id") ?: 0).toLong()
                    val cancelled = call.argument<Boolean>("cancelled") ?: false
                    controller.endContinuousGesture(id, cancelled) { ack ->
                        result.success(ack.wireName)
                    }
                }

                "updateInputDiagnostics" -> {
                    val phase = call.argument<String>("phase") ?: "idle"
                    val sessionId = call.argument<Number>("sessionId")?.toLong()
                    controller.updateInputDiagnostics(phase, sessionId)
                    result.success(null)
                }

                "systemAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    result.success(controller.systemAction(action))
                }

                "updateConfig" -> {
                    val pointerSpeed = (call.argument<Number>("pointerSpeed") ?: 1.8).toFloat()
                    val longPressDurationMs = (call.argument<Number>("longPressDurationMs") ?: 1000).toLong()
                    val showCursor = call.argument<Boolean>("showCursor") ?: true
                    val cursorIdleTimeoutMs = (call.argument<Number>("cursorIdleTimeoutMs") ?: 3000).toLong()
                    val externalHomePackage = call.argument<String>("externalHomePackage")
                    val externalHomeActivity = call.argument<String>("externalHomeActivity")
                    val preferredDisplayModeId = call.argument<Int>("preferredDisplayModeId")
                    controller.updateConfig(
                        pointerSpeed,
                        longPressDurationMs,
                        showCursor,
                        cursorIdleTimeoutMs,
                        externalHomePackage,
                        externalHomeActivity,
                        preferredDisplayModeId,
                    )
                    result.success(null)
                }

                "getHomeApps" ->
                    result.success(controller.getHomeApps().map { it.toMap() })

                "getInstalledApps" -> loadInstalledAppsAsync(result)

                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val activityName = call.argument<String>("activityName") ?: ""
                    loadAppIconAsync(packageName, activityName, result)
                }

                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val activityName = call.argument<String>("activityName") ?: ""
                    result.success(controller.launchApp(packageName, activityName))
                }

                "getDiagnostics" ->
                    result.success(controller.getDiagnostics().toMap())

                "isAccessibilityEnabled" ->
                    result.success(controller.isAccessibilityEnabled())

                "openAccessibilitySettings" -> {
                    context.startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    result.success(null)
                }

                "setResidentMonitoring" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    result.success(DisplayMonitorService.setEnabled(context, enabled))
                }

                else -> result.notImplemented()
            }
        } catch (e: ExternalTouchpadException) {
            result.error(e.code, e.message, null)
        } catch (e: Exception) {
            result.error("unknown_error", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        controller.eventSink = { event -> events?.success(event) }
    }

    override fun onCancel(arguments: Any?) {
        controller.eventSink = null
    }

    /** PackageManager enumeration and PNG conversion must never block Flutter's platform thread. */
    private fun loadInstalledAppsAsync(result: MethodChannel.Result) {
        appListExecutor.execute {
            try {
                val apps = controller.getInstalledApps().map { it.toMap() }
                mainHandler.post { result.success(apps) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("installed_apps_failed", error.message, null)
                }
            }
        }
    }

    private fun loadAppIconAsync(
        packageName: String,
        activityName: String,
        result: MethodChannel.Result,
    ) {
        appListExecutor.execute {
            try {
                val icon = controller.getAppIcon(packageName, activityName)
                mainHandler.post { result.success(icon) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("app_icon_failed", error.message, null)
                }
            }
        }
    }
}
