package dev.mosim.desktop_mode.accessibility

import android.graphics.Rect

/**
 * 外部ディスプレイ上のカーソル座標の唯一の所有者。
 * 全ての移動・境界変更でこの座標が display bounds にクランプされる。
 */
class CursorState(private var bounds: Rect) {
    var x: Float = bounds.exactCenterX()
        private set
    var y: Float = bounds.exactCenterY()
        private set

    fun moveBy(dx: Float, dy: Float) {
        x = (x + dx).coerceIn(bounds.left.toFloat(), bounds.right.toFloat())
        y = (y + dy).coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat())
    }

    fun updateBounds(newBounds: Rect) {
        bounds = newBounds
        x = x.coerceIn(bounds.left.toFloat(), bounds.right.toFloat())
        y = y.coerceIn(bounds.top.toFloat(), bounds.bottom.toFloat())
    }
}
