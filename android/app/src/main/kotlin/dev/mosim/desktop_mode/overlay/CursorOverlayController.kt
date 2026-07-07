package dev.mosim.desktop_mode.overlay

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Rect
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import kotlin.math.roundToInt

private const val TAG = "CursorOverlay"

/**
 * Optional cursor overlay for the target external display.
 *
 * This must never become the external display's main content. If an OEM rejects
 * TYPE_ACCESSIBILITY_OVERLAY on the secondary display, input injection continues
 * without a visible cursor.
 */
class CursorOverlayController {
    private var windowManager: WindowManager? = null
    private var overlayView: CursorOverlayView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private var windowSizePx: Int = 0

    val isActive: Boolean
        get() = overlayView != null

    /**
     * [preferredDisplayModeId] が指定された場合、この overlay ウィンドウの
     * `WindowManager.LayoutParams.preferredDisplayModeId` に反映し、接続先ディスプレイに
     * 対応解像度/リフレッシュレートへの切り替えを要求する(ベストエフォート、
     * 対応していない機器では無視される)。カーソル非表示設定の場合はこのウィンドウ自体が
     * 作られないため、解像度の指定はカーソル表示が有効なときのみ効果を持つ。
     */
    fun show(appContext: Context, display: Display, bounds: Rect, preferredDisplayModeId: Int? = null): Boolean {
        hide()
        return try {
            val displayContext = appContext
                .createDisplayContext(display)
                .createWindowContext(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, null)
            val wm = displayContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val view = CursorOverlayView(displayContext)
            val size = view.preferredSizePx
            val params = WindowManager.LayoutParams(
                size,
                size,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = bounds.left
                y = bounds.top
                if (preferredDisplayModeId != null) {
                    this.preferredDisplayModeId = preferredDisplayModeId
                }
            }
            wm.addView(view, params)
            windowManager = wm
            overlayView = view
            layoutParams = params
            windowSizePx = size
            true
        } catch (t: Throwable) {
            Log.w(TAG, "Cursor overlay unavailable on display ${display.displayId}", t)
            windowManager = null
            overlayView = null
            layoutParams = null
            windowSizePx = 0
            false
        }
    }

    fun move(x: Float, y: Float) {
        val view = overlayView ?: return
        val wm = windowManager ?: return
        val params = layoutParams ?: return
        val half = windowSizePx / 2f
        params.x = (x - half).roundToInt()
        params.y = (y - half).roundToInt()
        try {
            wm.updateViewLayout(view, params)
            view.invalidate()
        } catch (t: Throwable) {
            Log.w(TAG, "Cursor overlay move failed", t)
        }
    }

    fun showTouchEffect(x: Float, y: Float) {
        move(x, y)
        overlayView?.showTouchEffect()
    }

    /**
     * カーソルの表示/非表示を切り替える。ウィンドウ自体は削除せず、[View] の visibility を
     * 変更するため、再表示も軽量。非表示中もタッチ注入は継続する。
     */
    fun setVisible(visible: Boolean) {
        val view = overlayView ?: return
        val target = if (visible) View.VISIBLE else View.INVISIBLE
        if (view.visibility == target) return
        view.visibility = target
        view.invalidate()
    }

    fun hide() {
        try {
            overlayView?.let { windowManager?.removeView(it) }
        } catch (t: Throwable) {
            Log.w(TAG, "Cursor overlay remove failed", t)
        }
        windowManager = null
        overlayView = null
        layoutParams = null
        windowSizePx = 0
    }
}
