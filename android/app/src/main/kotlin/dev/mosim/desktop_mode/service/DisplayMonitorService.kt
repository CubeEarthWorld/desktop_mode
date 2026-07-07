package dev.mosim.desktop_mode.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.os.IBinder
import android.view.Display
import dev.mosim.desktop_mode.DesktopModeController
import dev.mosim.desktop_mode.MainActivity

private const val NOTIFICATION_CHANNEL_ID = "desktop_mode_monitor"
private const val NOTIFICATION_ID = 1

/**
 * 常駐監視(設定 ON のときのみ起動する Foreground Service)。
 * 外部ディスプレイ検出時に MainActivity 起動を試み、
 * バックグラウンド起動制限で失敗しても「タップして開く」通知が残る(仕様 R5)。
 */
class DisplayMonitorService : Service() {

    companion object {
        fun setEnabled(context: Context, enabled: Boolean): Boolean {
            val intent = Intent(context, DisplayMonitorService::class.java)
            if (enabled) {
                context.startForegroundService(intent)
            } else {
                context.stopService(intent)
            }
            return true
        }
    }

    private lateinit var displayManager: DisplayManager

    private val listener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {
            if (displayId != Display.DEFAULT_DISPLAY) launchTouchpad()
        }

        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {}
    }

    override fun onCreate() {
        super.onCreate()
        displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(listener, null)
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onDestroy() {
        displayManager.unregisterDisplayListener(listener)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun launchTouchpad() {
        try {
            startActivity(
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (e: Throwable) {
            DesktopModeController.getInstance(applicationContext)
                .recordError("activity_launch_denied", e.message ?: "起動を開始できません")
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "外部ディスプレイ監視",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Desktop Touchpad")
            .setContentText("タップしてタッチパッドを開く")
            .setSmallIcon(android.R.drawable.ic_menu_myplaces)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
