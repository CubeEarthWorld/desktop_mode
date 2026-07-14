package com.xignal.external_touchpad.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Rect
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.InputDevice
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import kotlin.math.roundToInt

private const val TAG = "SoftKeyboardCoordinator"
private const val MAX_EDITABLE_NODE_SCAN = 1024

internal enum class SoftKeyboardPolicy {
    SYSTEM,
    HIDDEN,
    FORCE_SOFT,
}

internal fun resolveSoftKeyboardPolicy(
    externalSessionActive: Boolean,
    dismissedByTouchpad: Boolean,
    hasHardwareKeyboard: Boolean,
): SoftKeyboardPolicy = when {
    !externalSessionActive -> SoftKeyboardPolicy.SYSTEM
    dismissedByTouchpad -> SoftKeyboardPolicy.HIDDEN
    hasHardwareKeyboard -> SoftKeyboardPolicy.SYSTEM
    else -> SoftKeyboardPolicy.FORCE_SOFT
}

/**
 * Owns the complete soft-keyboard policy for an external-display session.
 *
 * The session coordinator only reports lifecycle and pointer events. Hardware-keyboard
 * detection, Accessibility show modes, and editable-node hit testing stay encapsulated here.
 */
class SoftKeyboardCoordinator(
    context: Context,
    private val onError: (code: String, message: String) -> Unit,
) : InputManager.InputDeviceListener {
    private val inputManager = context.getSystemService(InputManager::class.java)
    private val callbackHandler = Handler(Looper.getMainLooper())

    private var accessibilityService: AccessibilityService? = null
    private var externalSessionActive = false
    private var dismissedByTouchpad = false
    private var hasHardwareKeyboard = detectHardwareKeyboard()

    init {
        inputManager?.registerInputDeviceListener(this, callbackHandler)
    }

    fun attach(service: AccessibilityService) {
        accessibilityService = service
        applyShowMode()
    }

    fun detach(service: AccessibilityService) {
        if (accessibilityService !== service) return
        setShowMode(service, AccessibilityService.SHOW_MODE_AUTO)
        accessibilityService = null
    }

    fun onSessionStarted() {
        externalSessionActive = true
        dismissedByTouchpad = false
        applyShowMode()
    }

    fun onSessionStopped() {
        externalSessionActive = false
        dismissedByTouchpad = false
        applyShowMode()
    }

    fun dismiss() {
        if (!externalSessionActive) return
        dismissedByTouchpad = true
        applyShowMode()
    }

    // `softKeyboardController.setShowMode` はディスプレイ単位ではなくシステム全体に
    // 効くグローバル設定。そのため、外部ディスプレイ以外(本体側の検索欄など)で
    // 編集可能な要素がフォーカスされた場合でも解除しないと、タッチパッド操作で
    // 一度 HIDDEN にした後は本体側でテキスト欄をタップしてもソフトキーボードが
    // 一切開かなくなってしまう。
    fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_VIEW_FOCUSED ||
            event.source?.let(::isEditableNode) != true
        ) {
            return
        }
        dismissedByTouchpad = false
        applyShowMode()
    }

    fun prepareForPointerAction(displayId: Int, x: Float, y: Float) {
        val service = accessibilityService ?: return
        if (!dismissedByTouchpad ||
            !isEditableNodeAt(service, displayId, x.roundToInt(), y.roundToInt())
        ) {
            return
        }
        dismissedByTouchpad = false
        applyShowMode()
    }

    override fun onInputDeviceAdded(deviceId: Int) = refreshHardwareKeyboardState()

    override fun onInputDeviceRemoved(deviceId: Int) = refreshHardwareKeyboardState()

    override fun onInputDeviceChanged(deviceId: Int) = refreshHardwareKeyboardState()

    private fun applyShowMode() {
        val service = accessibilityService ?: return
        val policy = resolveSoftKeyboardPolicy(
            externalSessionActive = externalSessionActive,
            dismissedByTouchpad = dismissedByTouchpad,
            hasHardwareKeyboard = hasHardwareKeyboard,
        )
        val showMode = when (policy) {
            SoftKeyboardPolicy.SYSTEM -> AccessibilityService.SHOW_MODE_AUTO
            SoftKeyboardPolicy.HIDDEN -> AccessibilityService.SHOW_MODE_HIDDEN
            SoftKeyboardPolicy.FORCE_SOFT -> AccessibilityService.SHOW_MODE_IGNORE_HARD_KEYBOARD
        }
        val accepted = setShowMode(service, showMode)
        if (!accepted && policy == SoftKeyboardPolicy.FORCE_SOFT) {
            onError(
                "soft_keyboard_mode_failed",
                "Android rejected the request to show the software keyboard",
            )
        }
    }

    private fun setShowMode(service: AccessibilityService, showMode: Int): Boolean = try {
        service.softKeyboardController.setShowMode(showMode)
    } catch (error: RuntimeException) {
        Log.w(TAG, "Unable to update soft keyboard show mode", error)
        false
    }

    private fun detectHardwareKeyboard(): Boolean {
        val manager = inputManager ?: return false
        return manager.inputDeviceIds
            .asSequence()
            .mapNotNull(manager::getInputDevice)
            .any { device ->
                device.isEnabled &&
                    !device.isVirtual &&
                    device.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC
            }
    }

    private fun refreshHardwareKeyboardState() {
        val detected = detectHardwareKeyboard()
        if (detected == hasHardwareKeyboard) return
        hasHardwareKeyboard = detected
        dismissedByTouchpad = false
        applyShowMode()
    }

    private fun isEditableNodeAt(
        service: AccessibilityService,
        displayId: Int,
        x: Int,
        y: Int,
    ): Boolean {
        val windows = service.windowsOnAllDisplays[displayId] ?: return false
        for (window in windows.sortedByDescending { it.layer }) {
            if (window.type == AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY ||
                window.type == AccessibilityWindowInfo.TYPE_INPUT_METHOD
            ) {
                continue
            }
            val root = window.root ?: continue
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            var visited = 0
            while (queue.isNotEmpty() && visited++ < MAX_EDITABLE_NODE_SCAN) {
                val node = queue.removeFirst()
                val bounds = Rect()
                node.getBoundsInScreen(bounds)
                if (bounds.contains(x, y) && isEditableNode(node)) return true
                for (index in 0 until node.childCount) {
                    node.getChild(index)?.let(queue::addLast)
                }
            }
        }
        return false
    }

    private fun isEditableNode(node: AccessibilityNodeInfo): Boolean =
        node.isEditable ||
            node.actionList.any { it.id == AccessibilityNodeInfo.ACTION_SET_TEXT }
}
