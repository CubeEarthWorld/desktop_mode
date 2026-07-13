package com.xignal.external_touchpad.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import com.xignal.external_touchpad.ExternalTouchpadController

class RemoteInputAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        ExternalTouchpadController.getInstance(applicationContext).attachAccessibilityService(this)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        ExternalTouchpadController.getInstance(applicationContext).onAccessibilityEvent(event)
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        ExternalTouchpadController.getInstance(applicationContext).detachAccessibilityService(this)
        return super.onUnbind(intent)
    }
}
