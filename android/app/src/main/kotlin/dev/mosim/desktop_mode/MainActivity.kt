package dev.mosim.desktop_mode

import android.os.Bundle
import dev.mosim.desktop_mode.platform.DesktopModeChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

private const val CONTROL_CHANNEL = "desktop_mode/control"
private const val EVENT_CHANNEL = "desktop_mode/display_events"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val controller = DesktopModeController.getInstance(applicationContext)
        val channel = DesktopModeChannel(applicationContext, controller)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler(channel)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(channel)
    }

    override fun onResume() {
        super.onResume()
        // 外部ディスプレイ接続済みでセッションが未開始の場合(常駐監視 Service からの起動や
        // プロセス復帰時など)、ここで自動的にセッションを開始しホームアプリを起動する。
        DesktopModeController.getInstance(applicationContext).ensureSessionAndHome()
    }
}
