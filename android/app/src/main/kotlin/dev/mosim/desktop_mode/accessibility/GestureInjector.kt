package dev.mosim.desktop_mode.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.Log

private const val TAG = "GestureInjector"

/**
 * tap / swipe / ドラッグ / 2本指ジェスチャーの注入を担う。
 *
 * Android の [AccessibilityService.dispatchGesture] は同時に処理できるジェスチャーを
 * 1つしか持たず、willContinue=true で [continueStroke] を使った複数回の dispatch は
 * 実機（特に外部ディスプレイ）で即座にシステムキャンセルされる。ここではその制約を
 * 受け入れ、ドラッグ/2本指移動を「前回位置から現在位置への短いスワイプ」を連続して
 * dispatch する方式でエミュレートする。完全なドラッグ＆ドロップ（指を離さずに物体を
 * 運ぶ動作）には限界があるが、スクロール・スワイプ・ピンチ等の一般的な操作はこれで
 * 外部ディスプレイ側に届く。
 */
class GestureInjector {
    var lastGestureResult: String = "none"
        private set

    /** pointerUp/twoFingerEnd の結果。呼び出し側はこれを見て「本当に busy」か「既に終了済み」かを区別する。 */
    enum class GestureAck { ACCEPTED, ALREADY_ENDED, REJECTED_BUSY, DISPATCH_FAILED }

    private sealed interface ActiveGesture {
        object None : ActiveGesture
        object SingleShot : ActiveGesture

        class Drag(
            val displayId: Int,
            var lastX: Float,
            var lastY: Float,
        ) : ActiveGesture

        class TwoFinger(
            val displayId: Int,
            var lastAX: Float,
            var lastAY: Float,
            var lastBX: Float,
            var lastBY: Float,
        ) : ActiveGesture
    }

    private var active: ActiveGesture = ActiveGesture.None

    /**
     * セッション終了時などに強制的に内部状態を破棄する。
     * ドラッグ/2本指ジェスチャの途中でセッションが終了する(例: 外部ディスプレイ切断)と
     * pointerUp/twoFingerScrollEnd が一度も呼ばれずに進行中状態が残り、それ以降ずっと
     * 「タッチできない」状態に陥ってしまうため、必ずここで解放する。
     */
    fun reset() {
        if (active != ActiveGesture.None) {
            Log.w(TAG, "Force-resetting stuck gesture state (was=${active::class.simpleName})")
        }
        active = ActiveGesture.None
    }

    fun tap(
        service: AccessibilityService,
        displayId: Int,
        x: Float,
        y: Float,
        durationMs: Long,
        onOutcome: (String) -> Unit,
    ): Boolean {
        if (active != ActiveGesture.None) {
            lastGestureResult = "busy"
            Log.w(TAG, "tap rejected: active=${active::class.simpleName}")
            return false
        }

        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(MIN_DURATION_MS))

        active = ActiveGesture.SingleShot
        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(stroke),
            owner = ActiveGesture.SingleShot,
            onCompleted = { active = ActiveGesture.None },
            onOutcome = onOutcome,
        )
        if (!accepted) {
            active = ActiveGesture.None
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "tap dispatch rejected by AccessibilityService")
        }
        return accepted
    }

    fun swipe(
        service: AccessibilityService,
        displayId: Int,
        startX: Float,
        startY: Float,
        endX: Float,
        endY: Float,
        durationMs: Long,
        onOutcome: (String) -> Unit,
    ): Boolean {
        if (active != ActiveGesture.None) {
            lastGestureResult = "busy"
            Log.w(TAG, "swipe rejected: active=${active::class.simpleName}")
            return false
        }

        val path = Path().apply {
            moveTo(startX, startY)
            lineTo(endX, endY)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs.coerceAtLeast(MIN_DURATION_MS))

        active = ActiveGesture.SingleShot
        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(stroke),
            owner = ActiveGesture.SingleShot,
            onCompleted = { active = ActiveGesture.None },
            onOutcome = onOutcome,
        )
        if (!accepted) {
            active = ActiveGesture.None
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "swipe dispatch rejected by AccessibilityService")
        }
        return accepted
    }

    /**
     * ドラッグ開始。現在位置で短い接触 gesture を dispatch し、以後の [pointerMove] は
     * 前回位置からの短いスワイプとして連続 dispatch する。
     */
    fun pointerDown(
        service: AccessibilityService,
        displayId: Int,
        x: Float,
        y: Float,
        onOutcome: (String) -> Unit,
    ): Boolean {
        if (active != ActiveGesture.None) {
            lastGestureResult = "busy"
            Log.w(TAG, "pointerDown rejected: active=${active::class.simpleName}")
            return false
        }

        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, CONTACT_DURATION_MS)
        active = ActiveGesture.Drag(displayId, x, y)

        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(stroke),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        if (!accepted) {
            active = ActiveGesture.None
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "pointerDown dispatch rejected by AccessibilityService")
        }
        return accepted
    }

    /**
     * ドラッグ中の移動。前回位置から現在位置への短いスワイプを dispatch する。
     * 前回のジェスチャーがまだ処理中でも、最新の座標を届けるため新しいジェスチャーで
     * 上書きする（Android は同サービスからの新規 gesture で前のものをキャンセルする）。
     */
    fun pointerMove(
        service: AccessibilityService,
        displayId: Int,
        x: Float,
        y: Float,
        onOutcome: (String) -> Unit,
    ): Boolean {
        val drag = active as? ActiveGesture.Drag
        if (drag == null || displayId != drag.displayId) {
            Log.w(TAG, "pointerMove ignored: no active drag stroke for display $displayId")
            return false
        }

        val path = Path().apply {
            moveTo(drag.lastX, drag.lastY)
            lineTo(x, y)
        }
        drag.lastX = x
        drag.lastY = y

        dispatchGesture(
            service,
            displayId,
            listOf(GestureDescription.StrokeDescription(path, 0, SEGMENT_DURATION_MS)),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        return true
    }

    /**
     * ドラッグ終了。最後の位置で短いリリース gesture を dispatch する。
     * 既に他のイベント(システムによるキャンセル等)で状態がクリア済みだった場合は
     * [GestureAck.ALREADY_ENDED] を返す。
     */
    fun pointerUp(
        service: AccessibilityService,
        displayId: Int,
        x: Float,
        y: Float,
        onOutcome: (String) -> Unit,
    ): GestureAck {
        val drag = active as? ActiveGesture.Drag
        if (drag == null || displayId != drag.displayId) {
            Log.w(TAG, "pointerUp ignored: no active drag stroke for display $displayId")
            return GestureAck.ALREADY_ENDED
        }

        active = ActiveGesture.None
        val path = Path().apply {
            moveTo(x, y)
            lineTo(x, y)
        }
        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(GestureDescription.StrokeDescription(path, 0, RELEASE_DURATION_MS)),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        if (!accepted) {
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "pointerUp dispatch rejected by AccessibilityService")
            return GestureAck.DISPATCH_FAILED
        }
        return GestureAck.ACCEPTED
    }

    /**
     * 2本指ジェスチャの開始。カーソル位置を中心に一定間隔の仮想2点で接触 gesture を
     * dispatch する。
     */
    fun twoFingerStart(
        service: AccessibilityService,
        displayId: Int,
        ax: Float,
        ay: Float,
        bx: Float,
        by: Float,
        onOutcome: (String) -> Unit,
    ): Boolean {
        if (active != ActiveGesture.None) {
            lastGestureResult = "busy"
            Log.w(TAG, "twoFingerStart rejected: active=${active::class.simpleName}")
            return false
        }
        Log.d(TAG, "twoFingerStart display=$displayId a=($ax,$ay) b=($bx,$by)")

        val pathA = Path().apply {
            moveTo(ax, ay)
            lineTo(ax, ay)
        }
        val pathB = Path().apply {
            moveTo(bx, by)
            lineTo(bx, by)
        }
        val strokeA = GestureDescription.StrokeDescription(pathA, 0, CONTACT_DURATION_MS)
        val strokeB = GestureDescription.StrokeDescription(pathB, 0, CONTACT_DURATION_MS)
        active = ActiveGesture.TwoFinger(displayId, ax, ay, bx, by)

        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(strokeA, strokeB),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        if (!accepted) {
            active = ActiveGesture.None
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "twoFingerStart dispatch rejected by AccessibilityService")
        }
        return accepted
    }

    fun twoFingerMove(
        service: AccessibilityService,
        displayId: Int,
        ax: Float,
        ay: Float,
        bx: Float,
        by: Float,
        onOutcome: (String) -> Unit,
    ): Boolean {
        val twoFinger = active as? ActiveGesture.TwoFinger
        if (twoFinger == null || displayId != twoFinger.displayId) {
            Log.w(TAG, "twoFingerMove ignored: no active two-finger gesture")
            return false
        }

        val pathA = Path().apply {
            moveTo(twoFinger.lastAX, twoFinger.lastAY)
            lineTo(ax, ay)
        }
        val pathB = Path().apply {
            moveTo(twoFinger.lastBX, twoFinger.lastBY)
            lineTo(bx, by)
        }
        twoFinger.lastAX = ax
        twoFinger.lastAY = ay
        twoFinger.lastBX = bx
        twoFinger.lastBY = by

        dispatchGesture(
            service,
            displayId,
            listOf(
                GestureDescription.StrokeDescription(pathA, 0, SEGMENT_DURATION_MS),
                GestureDescription.StrokeDescription(pathB, 0, SEGMENT_DURATION_MS),
            ),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        return true
    }

    fun twoFingerEnd(
        service: AccessibilityService,
        displayId: Int,
        ax: Float,
        ay: Float,
        bx: Float,
        by: Float,
        onOutcome: (String) -> Unit,
    ): GestureAck {
        val twoFinger = active as? ActiveGesture.TwoFinger
        if (twoFinger == null || displayId != twoFinger.displayId) {
            Log.w(TAG, "twoFingerEnd ignored: no active two-finger gesture")
            return GestureAck.ALREADY_ENDED
        }

        active = ActiveGesture.None
        val pathA = Path().apply {
            moveTo(ax, ay)
            lineTo(ax, ay)
        }
        val pathB = Path().apply {
            moveTo(bx, by)
            lineTo(bx, by)
        }

        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(
                GestureDescription.StrokeDescription(pathA, 0, RELEASE_DURATION_MS),
                GestureDescription.StrokeDescription(pathB, 0, RELEASE_DURATION_MS),
            ),
            owner = ActiveGesture.None,
            onCompleted = {},
            onOutcome = onOutcome,
        )
        if (!accepted) {
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "twoFingerEnd dispatch rejected by AccessibilityService")
            return GestureAck.DISPATCH_FAILED
        }
        return GestureAck.ACCEPTED
    }

    /**
     * 2本指スワイプ（フリック）。開始位置から終了位置まで2点を同じ量だけ動かす
     * 単発ジェスチャーを dispatch する。スクロールとの区別は Flutter 側で行う。
     */
    fun twoFingerSwipe(
        service: AccessibilityService,
        displayId: Int,
        startAX: Float,
        startAY: Float,
        startBX: Float,
        startBY: Float,
        endAX: Float,
        endAY: Float,
        endBX: Float,
        endBY: Float,
        durationMs: Long,
        onOutcome: (String) -> Unit,
    ): Boolean {
        if (active != ActiveGesture.None) {
            lastGestureResult = "busy"
            Log.w(TAG, "twoFingerSwipe rejected: active=${active::class.simpleName}")
            return false
        }

        val pathA = Path().apply {
            moveTo(startAX, startAY)
            lineTo(endAX, endAY)
        }
        val pathB = Path().apply {
            moveTo(startBX, startBY)
            lineTo(endBX, endBY)
        }
        val strokeA = GestureDescription.StrokeDescription(
            pathA,
            0,
            durationMs.coerceAtLeast(MIN_DURATION_MS),
        )
        val strokeB = GestureDescription.StrokeDescription(
            pathB,
            0,
            durationMs.coerceAtLeast(MIN_DURATION_MS),
        )

        active = ActiveGesture.SingleShot
        val accepted = dispatchGesture(
            service,
            displayId,
            listOf(strokeA, strokeB),
            owner = ActiveGesture.SingleShot,
            onCompleted = { active = ActiveGesture.None },
            onOutcome = onOutcome,
        )
        if (!accepted) {
            active = ActiveGesture.None
            lastGestureResult = "dispatch_failed"
            Log.w(TAG, "twoFingerSwipe dispatch rejected by AccessibilityService")
        }
        return accepted
    }

    /**
     * すべての `dispatchGesture` 呼び出しの共通実装(DRY)。tap/swipe などの
     * 単発ジェスチャーでは [owner] を渡して完了時に [active] をクリアする。
     * ドラッグ/2本指の連続 dispatch では [owner] に [ActiveGesture.None] を渡し、
     * 完了コールバックは空にする（連続 dispatch 中に active を変えない）。
     */
    private fun dispatchGesture(
        service: AccessibilityService,
        displayId: Int,
        strokes: List<GestureDescription.StrokeDescription>,
        owner: ActiveGesture,
        onCompleted: () -> Unit,
        onOutcome: (String) -> Unit,
    ): Boolean {
        val builder = GestureDescription.Builder().setDisplayId(displayId)
        strokes.forEach { builder.addStroke(it) }
        val gesture = builder.build()

        val accepted = service.dispatchGesture(
            gesture,
            object : AccessibilityService.GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    lastGestureResult = "completed"
                    if (active === owner && owner !== ActiveGesture.None) onCompleted()
                    onOutcome("completed")
                }

                override fun onCancelled(gestureDescription: GestureDescription?) {
                    lastGestureResult = "cancelled"
                    if (active === owner && owner !== ActiveGesture.None) {
                        Log.w(TAG, "gesture cancelled by system (display=$displayId); resetting state")
                        active = ActiveGesture.None
                    }
                    onOutcome("cancelled")
                }
            },
            null,
        )
        if (!accepted) {
            Log.w(TAG, "dispatchGesture rejected by AccessibilityService (display=$displayId)")
        }
        return accepted
    }

    private companion object {
        /** StrokeDescription に渡せる最小 duration。0 や負値は例外を起こす。 */
        const val MIN_DURATION_MS = 1L

        /** タッチ開始時の短い接触時間。長すぎるとカーソル移動との切り替わりが遅くなる。 */
        const val CONTACT_DURATION_MS = 50L

        /** 移動セグメントの長さ。短くしすぎるとシステム側で無視されることがある。 */
        const val SEGMENT_DURATION_MS = 16L

        /** タッチ終了時の短いリリース時間。 */
        const val RELEASE_DURATION_MS = 16L
    }
}
