package dev.mosim.desktop_mode.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import dev.mosim.desktop_mode.DesktopModeController

/**
 * OS 操作(global action)とジェスチャ注入のための Accessibility 権限を保持するだけの Service。
 * ロジックは持たず、接続状態を `DesktopModeController` に伝える(SRP)。
 */
class RemoteInputAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        DesktopModeController.getInstance(applicationContext).attachAccessibilityService(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // ウィンドウ内容は取得しない。接続状態の把握のみに Service を利用する。
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        DesktopModeController.getInstance(applicationContext).detachAccessibilityService(this)
        return super.onUnbind(intent)
    }
}
