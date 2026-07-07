package dev.mosim.desktop_mode

import android.graphics.Rect
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
        excludeSystemGesturesFromTouchpad()
    }

    /**
     * タッチパッド画面全体をシステムジェスチャーの除外領域にする。OEM 独自の
     * 画面端スワイプ/長押しドラッグ機能(マルチウィンドウ分割など)がタッチパッドの
     * 指の動きを途中で横取りすると、Flutter 側に move が届かず「動かさず離した」
     * (長押し/クリック)と誤認識されたり、ドラッグ/スワイプが不自然に途切れたりする。
     * 除外領域を宣言することで、OS 標準のジェスチャーナビゲーションについては
     * このタッチパッド領域内での横取りを防げる(レイアウト確定後でないと
     * View のサイズが取れないため、decorView の post 内で行う)。
     */
    private fun excludeSystemGesturesFromTouchpad() {
        val decorView = window.decorView
        decorView.post {
            val width = decorView.width
            val height = decorView.height
            if (width > 0 && height > 0) {
                decorView.systemGestureExclusionRects = listOf(Rect(0, 0, width, height))
            }
        }
    }
}
