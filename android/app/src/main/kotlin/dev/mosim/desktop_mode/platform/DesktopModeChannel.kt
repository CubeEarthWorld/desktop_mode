package dev.mosim.desktop_mode.platform

import android.content.Context
import android.content.Intent
import android.provider.Settings
import dev.mosim.desktop_mode.DesktopModeController
import dev.mosim.desktop_mode.DesktopModeException
import dev.mosim.desktop_mode.service.DisplayMonitorService
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel/EventChannel の終端。引数の取り出しと Map への変換、
 * `DesktopModeController` へのルーティングのみを行い、ロジックは一切持たない(SRP)。
 */
class DesktopModeChannel(
    private val context: Context,
    private val controller: DesktopModeController,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

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

                "moveCursor" -> {
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    controller.moveCursor(dx, dy)
                    result.success(null)
                }

                "leftClick" -> {
                    controller.leftClick()
                    result.success(null)
                }

                "longPress" -> {
                    controller.longPress()
                    result.success(null)
                }

                "showTouchEffectAtCursor" -> {
                    controller.showTouchEffectAtCursor()
                    result.success(null)
                }

                "pointerDown" -> {
                    controller.pointerDown()
                    result.success(null)
                }

                "pointerMove" -> {
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    controller.pointerMove(dx, dy)
                    result.success(null)
                }

                "pointerUp" -> {
                    controller.pointerUp()
                    result.success(null)
                }

                "twoFingerScrollStart" -> {
                    controller.twoFingerScrollStart()
                    result.success(null)
                }

                "twoFingerScrollBy" -> {
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    controller.twoFingerScrollBy(dx, dy)
                    result.success(null)
                }

                "twoFingerScrollEnd" -> {
                    controller.twoFingerScrollEnd()
                    result.success(null)
                }

                "twoFingerSwipe" -> {
                    val dx = (call.argument<Number>("dx") ?: 0).toFloat()
                    val dy = (call.argument<Number>("dy") ?: 0).toFloat()
                    controller.twoFingerSwipe(dx, dy)
                    result.success(null)
                }

                "systemAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    result.success(controller.systemAction(action))
                }

                "updateConfig" -> {
                    val pointerSpeed = (call.argument<Number>("pointerSpeed") ?: 1.8).toFloat()
                    val longPressDurationMs = (call.argument<Number>("longPressDurationMs") ?: 550).toLong()
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

                "getInstalledApps" ->
                    result.success(controller.getInstalledApps().map { it.toMap() })

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
        } catch (e: DesktopModeException) {
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
}
