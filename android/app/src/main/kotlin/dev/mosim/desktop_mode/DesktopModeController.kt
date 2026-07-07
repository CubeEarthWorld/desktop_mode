package dev.mosim.desktop_mode

import android.accessibilityservice.AccessibilityService
import android.app.ActivityOptions
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.Display
import java.io.ByteArrayOutputStream
import dev.mosim.desktop_mode.accessibility.CursorState
import dev.mosim.desktop_mode.accessibility.GestureInjector
import dev.mosim.desktop_mode.accessibility.InjectorConfig
import dev.mosim.desktop_mode.display.DisplayInfo
import dev.mosim.desktop_mode.display.DisplayModeInfo
import dev.mosim.desktop_mode.display.DisplaySessionListener
import dev.mosim.desktop_mode.display.DisplaySessionManager
import dev.mosim.desktop_mode.overlay.CursorOverlayController
import org.json.JSONObject

private const val TAG = "DesktopModeController"
private const val HOME_LAUNCH_COOLDOWN_MS = 1500L
private const val TWO_FINGER_INITIAL_SPREAD_PX = 80f
private const val SWIPE_DISTANCE_SCALE = 4f
private const val SWIPE_DURATION_MS = 150L

/**
 * アプリ全体の唯一の調停者。認識(Flutter)/注入(GestureInjector)/
 * 座標管理(CursorState)/表示(CursorOverlayController)/検出(DisplaySessionManager)を
 * それぞれ単機能のクラスに閉じ込め、本クラスは接続と状態遷移のみを行う(SRP)。
 */
class DesktopModeController private constructor(private val appContext: Context) :
    DisplaySessionListener {

    companion object {
        @Volatile private var instance: DesktopModeController? = null

        fun getInstance(context: Context): DesktopModeController =
            instance ?: synchronized(this) {
                instance ?: DesktopModeController(context.applicationContext).also { instance = it }
            }
    }

    /** DesktopModeChannel が onListen/onCancel で差し替える送出口。 */
    var eventSink: ((Map<String, Any?>) -> Unit)? = null

    private val displaySessionManager = DisplaySessionManager(appContext)
    private val gestureInjector = GestureInjector()
    private val overlayController = CursorOverlayController()

    private var accessibilityService: AccessibilityService? = null
    private var cursorState: CursorState? = null
    private var targetDisplay: Display? = null
    private var status: SessionStatus = SessionStatus.IDLE
    private var config: InjectorConfig = readConfigFromPrefs()
    private var lastError: String? = null
    private var lastHomeLaunchAtMs: Long = 0L
    private var twoFingerPointA: PointF? = null
    private var twoFingerPointB: PointF? = null

    private val cursorIdleHandler = Handler(Looper.getMainLooper())
    private val cursorIdleRunnable = Runnable { hideCursorForIdle() }
    private var cursorIdleHidden = false

    /**
     * 接続エピソード(接続してから切断されるまで)ごとに、自動ホーム起動を
     * 一度だけ行ったディスプレイ ID を記録する。Flutter 側のウィジェット
     * 再マウント等で `startSession` 相当の処理が何度呼ばれても、同じ接続の
     * 間はホームを再起動しない(セッションのライフサイクルは Android 側だけが
     * 所有する唯一の情報源であるべき、という設計方針)。
     */
    private val claimedDisplays: MutableSet<Int> = mutableSetOf()

    init {
        displaySessionManager.start(this)
        // `DisplayManager.DisplayListener.onDisplayAdded` はリスナー登録**後**に
        // 新規接続されたディスプレイでしか発火しない。そのため、アプリプロセスが
        // 再起動された時点で外部ディスプレイが既に接続済みだった場合、
        // onDisplayAdded は二度と呼ばれずセッションが永久に IDLE のままになってしまう
        // (結果として launchHomeOnDisplay も呼ばれず、外部ディスプレイが
        // OS既定のミラーリング表示のまま放置される)。ここで一度だけ「既に接続済みの
        // ディスプレイ」を能動的にチェックし、条件が揃っていれば同じ経路で
        // クレームする。
        tryAutoClaimConnectedDisplay()
    }

    /**
     * 自動起動条件(autoStart 設定 + Accessibility 有効)が揃った状態で、
     * まだクレームしていない外部ディスプレイが既に接続されている場合、
     * `onDisplayAdded` と同じ経路でセッションを開始する。
     * `init` (プロセス起動時)と `attachAccessibilityService`
     * (Accessibility が後から接続した場合)の両方から呼ばれる、この種の
     * 「取りこぼし」を防ぐ唯一の入口(DRY)。
     */
    private fun tryAutoClaimConnectedDisplay() {
        if (status == SessionStatus.ACTIVE) return
        if (!readAutoStartFromPrefs() || !isAccessibilityEnabled()) return
        val display = displaySessionManager.pickAutoTarget() ?: return
        if (display.displayId in claimedDisplays) return
        claimedDisplays += display.displayId
        activateSession(display)
    }

    // ---- Accessibility 接続状態(仕様 R10: push 通知) ----

    fun attachAccessibilityService(service: AccessibilityService) {
        accessibilityService = service
        config = readConfigFromPrefs()
        emitEvent(mapOf("type" to "accessibilityStateChanged", "enabled" to true))
        tryAutoClaimConnectedDisplay()
    }

    fun detachAccessibilityService(service: AccessibilityService) {
        if (accessibilityService === service) {
            accessibilityService = null
            // サービス切断中に組み立てていたジェスチャは二度と完了できないため、
            // 内部状態を破棄しておかないと再接続後もずっと busy のまま入力不能になる。
            gestureInjector.reset()
        }
        emitEvent(mapOf("type" to "accessibilityStateChanged", "enabled" to false))
    }

    fun isAccessibilityEnabled(): Boolean = accessibilityService != null

    // ---- DisplaySessionListener ----

    override fun onDisplayAdded(displayId: Int) {
        emitEvent(mapOf("type" to "displayAdded", "displayId" to displayId))
        // 自動起動の判断はここ(ネイティブ側の実ディスプレイ検出)だけで完結させる。
        // Flutter 側のどの画面が今どう表示されているかには一切依存しない。
        if (displayId in claimedDisplays) return
        if (!readAutoStartFromPrefs() || !isAccessibilityEnabled()) return
        val display = displaySessionManager.findDisplay(displayId) ?: return
        claimedDisplays += displayId
        activateSession(display)
    }

    override fun onDisplayRemoved(displayId: Int) {
        emitEvent(mapOf("type" to "displayRemoved", "displayId" to displayId))
        claimedDisplays -= displayId
        if (targetDisplay?.displayId == displayId || displaySessionManager.externalDisplays().isEmpty()) {
            stopSession()
            // 外部ディスプレイ切断時、Android は既定でそのディスプレイ上のタスクを
            // プライマリディスプレイ(スマホ本体)へ移動する(removeMode=MOVE_TO_PRIMARY)。
            // 何もしないと移動してきたタスクがタッチパッド画面を覆ってしまい、
            // 「スマホ側が外部ディスプレイのような表示になる」ように見える。
            // 先に Flutter 側をトップ画面に戻してから自アプリを前面へ戻し、
            // 必ずアプリのトップ画面が見える状態にする。
            emitEvent(mapOf("type" to "sessionStopped", "reason" to "displayRemoved"))
            bringOwnActivityToFront()
        }
    }

    private fun bringOwnActivityToFront() {
        try {
            val intent = Intent(appContext, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            appContext.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Unable to bring MainActivity to front after display removal", e)
        }
    }

    override fun onDisplayChanged(displayId: Int) {
        emitEvent(mapOf("type" to "displayChanged", "displayId" to displayId))
        val display = targetDisplay
        if (display != null && display.displayId == displayId) {
            val bounds = displaySessionManager.bounds(display)
            cursorState?.updateBounds(bounds)
            if (config.showCursor) {
                overlayController.show(
                    accessibilityService ?: appContext,
                    display,
                    bounds,
                    config.preferredDisplayModeId,
                )
                cursorState?.let { overlayController.move(it.x, it.y) }
                markCursorActivity()
            }
        }
    }

    // ---- DesktopModeChannel から呼ばれる公開 API ----

    fun getDisplays(): List<DisplayInfo> = displaySessionManager.listDisplays()

    /**
     * アプリが前面に戻った際、外部ディスプレイが接続されていてセッションが未開始なら
     * 自動的にセッションを開始しホームアプリを起動する。常駐監視 Service からの起動や
     * プロセス復帰時の取りこぼしを防ぐためのフォールバック入口。
     */
    fun ensureSessionAndHome() {
        if (status == SessionStatus.ACTIVE) return
        if (!isAccessibilityEnabled()) return
        val display = displaySessionManager.pickAutoTarget() ?: return
        if (display.displayId in claimedDisplays) return
        claimedDisplays += display.displayId
        activateSession(display)
    }

    /** 指定ディスプレイが対応する解像度/リフレッシュレートの一覧(設定画面の選択肢用)。 */
    fun getSupportedDisplayModes(displayId: Int): List<DisplayModeInfo> =
        displaySessionManager.getSupportedModes(displayId)

    fun getSessionState(): SessionState =
        SessionState(status, targetDisplay?.displayId, overlayController.isActive)

    /**
     * ユーザーの明示操作(手動でディスプレイを選んで接続するなど)専用の入口。
     * 既に同じディスプレイでセッションがアクティブな場合は no-op で現在の状態を
     * 返すだけにし、Flutter 側の再呼び出し(画面の再マウント等)でホームが
     * 再起動されることがないようにする(冪等性)。
     */
    fun startSession(requestedDisplayId: Int?): SessionState {
        val display = requestedDisplayId?.let { displaySessionManager.findDisplay(it) }
            ?: displaySessionManager.pickAutoTarget()
            ?: throw DesktopModeException("display_not_found", "外部ディスプレイが見つかりません")

        if (status == SessionStatus.ACTIVE && targetDisplay?.displayId == display.displayId) {
            return getSessionState()
        }
        claimedDisplays += display.displayId
        return activateSession(display)
    }

    /**
     * セッションを実際に開始する処理本体。`onDisplayAdded`(自動起動)と
     * `startSession`(手動起動)の両方から、それぞれのガード条件を通過した後にだけ
     * 呼ばれる唯一の実装(DRY)。
     */
    private fun activateSession(display: Display): SessionState {
        val bounds = displaySessionManager.bounds(display)
        targetDisplay = display
        cursorState = CursorState(bounds)
        status = SessionStatus.ACTIVE

        if (config.showCursor) {
            val shown = overlayController.show(
                accessibilityService ?: appContext,
                display,
                bounds,
                config.preferredDisplayModeId,
            )
            if (!shown) {
                lastError = "overlay_failed: cursor overlay unavailable"
                emitEvent(
                    mapOf(
                        "type" to "error",
                        "code" to "overlay_failed",
                        "message" to "カーソルoverlayを表示できません",
                    ),
                )
            }
            cursorState?.let { overlayController.move(it.x, it.y) }
            resetCursorIdleTimer()
        }

        // 接続直後の外部ディスプレイは何も表示されておらず真っ暗に見えるため、
        // ベストエフォートでホーム画面を表示しておく(OEM ランチャーが横向きの
        // 外部ディスプレイに対応していない端末では一時的に表示が乱れることがあるが、
        // 何も表示されないよりは改善となる)。
        lastHomeLaunchAtMs = SystemClock.elapsedRealtime()
        val homeLaunched = launchHomeOnDisplay(display.displayId)
        Log.d(TAG, "activateSession display=${display.displayId} homeLaunched=$homeLaunched")

        val state = getSessionState()
        emitEvent(
            mapOf(
                "type" to "sessionStarted",
                "status" to state.status.name.lowercase(),
                "targetDisplayId" to state.targetDisplayId,
                "overlayActive" to state.overlayActive,
            ),
        )
        return state
    }

    fun stopSession() {
        cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
        cursorIdleHidden = false
        overlayController.hide()
        targetDisplay = null
        cursorState = null
        status = SessionStatus.IDLE
        twoFingerPointA = null
        twoFingerPointB = null
        // ドラッグ/2本指ジェスチャの途中でセッションが終了すると(例: 外部ディスプレイ切断)
        // pointerUp/twoFingerScrollEnd が呼ばれないまま GestureInjector が busy=true で
        // 固まってしまい、以後ずっとタップできなくなる。ここで必ず解放する。
        gestureInjector.reset()
    }

    // ---- カーソルのアイドル非表示 ----

    private fun markCursorActivity() {
        if (cursorIdleHidden) {
            cursorIdleHidden = false
            overlayController.setVisible(true)
        }
        resetCursorIdleTimer()
    }

    private fun hideCursorForIdle() {
        if (!config.showCursor || config.cursorIdleTimeoutMs <= 0) return
        cursorIdleHidden = true
        overlayController.setVisible(false)
    }

    private fun resetCursorIdleTimer() {
        cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
        if (!config.showCursor || config.cursorIdleTimeoutMs <= 0) return
        cursorIdleHandler.postDelayed(cursorIdleRunnable, config.cursorIdleTimeoutMs)
    }

    fun moveCursor(dxPx: Float, dyPx: Float) {
        val cursor = cursorState
            ?: throw DesktopModeException("session_not_active", "セッションが開始されていません")
        cursor.moveBy(dxPx * config.pointerSpeed, dyPx * config.pointerSpeed)
        overlayController.move(cursor.x, cursor.y)
        markCursorActivity()
    }

    fun leftClick() {
        dispatchTap(durationMs = 50L)
        markCursorActivity()
    }

    /** Android のマウスカーソルには右クリックが無いため、右クリックの代替として
     *  現在カーソル位置に長押しタップを送る(長押しは大半のアプリでコンテキスト
     *  メニュー等、右クリック相当の操作として解釈される)。 */
    fun longPress() {
        dispatchTap(durationMs = config.longPressDurationMs)
        markCursorActivity()
    }

    fun showTouchEffectAtCursor() {
        val cursor = cursorState ?: return
        overlayController.showTouchEffect(cursor.x, cursor.y)
        markCursorActivity()
    }

    fun pointerDown() {
        markCursorActivity()
        dispatchDrag { service, displayId, x, y ->
            gestureInjector.pointerDown(
                service,
                displayId,
                x,
                y,
                onCancelledError("gesture_failed", "ドラッグ開始がキャンセルされました"),
            )
        }
    }

    fun pointerMove(dxPx: Float, dyPx: Float) {
        val cursor = cursorState
            ?: throw DesktopModeException("session_not_active", "セッションが開始されていません")
        cursor.moveBy(dxPx * config.pointerSpeed, dyPx * config.pointerSpeed)
        overlayController.move(cursor.x, cursor.y)
        markCursorActivity()

        val service = accessibilityService ?: return
        val display = targetDisplay ?: return
        val moved = gestureInjector.pointerMove(
            service,
            display.displayId,
            cursor.x,
            cursor.y,
            ignoreOutcome,
        )
        if (!moved) {
            // pointerDown が何らかの理由で届いていない/失敗している場合、pointerMove は
            // 何もせず無視されるだけで、カーソルの見た目だけが動いて実際のタッチ注入が
            // 一切送られない状態になってしまう(ドラッグしているように見えるのに外部
            // ディスプレイ側では何も起きない不具合の原因)。現在位置でドラッグを
            // 張り直し、以後の move が続けて反映されるようにする。
            gestureInjector.pointerDown(
                service,
                display.displayId,
                cursor.x,
                cursor.y,
                onCancelledError("gesture_failed", "ドラッグの再開がキャンセルされました"),
            )
        }
    }

    /**
     * ドラッグ終了。他の drag アクション(pointerDown 等)と異なり、
     * システムが既にジェスチャーをキャンセル済みだった場合([GestureAck.ALREADY_ENDED])は
     * 「busy」ではなく成功として扱う(ドラッグ自体は実質的に終わっているため)。
     * 本当に新規ジェスチャーが拒否された場合([GestureAck.REJECTED_BUSY]/
     * [GestureAck.DISPATCH_FAILED])だけ `gesture_busy` を投げる。
     */
    fun pointerUp() {
        markCursorActivity()
        val service = accessibilityService
            ?: throw DesktopModeException("accessibility_disabled", "Accessibility service is not enabled")
        val display = targetDisplay
        val cursor = cursorState
        if (display == null || cursor == null) {
            throw DesktopModeException("session_not_active", "Session is not active")
        }
        val ack = gestureInjector.pointerUp(
            service,
            display.displayId,
            cursor.x,
            cursor.y,
            onCancelledError("gesture_failed", "ドラッグ終了がキャンセルされました"),
        )
        if (ack == GestureInjector.GestureAck.REJECTED_BUSY || ack == GestureInjector.GestureAck.DISPATCH_FAILED) {
            throw DesktopModeException("gesture_busy", "A gesture is already running")
        }
    }

    /**
     * 2本指スクロールの開始。カーソル位置を中心に一定間隔の仮想2点を置き、
     * 以後は [twoFingerScrollBy] で常に**同じ量**だけ両点を動かす(タッチパッドは
     * 絶対座標を持たないため)。2点の間隔が常に一定に保たれるため、外部ディスプレイの
     * アプリからはピンチではなく常にスクロールとして解釈される。
     */
    fun twoFingerScrollStart() {
        markCursorActivity()
        val cursor = cursorState
            ?: throw DesktopModeException("session_not_active", "セッションが開始されていません")
        val a = PointF(cursor.x - TWO_FINGER_INITIAL_SPREAD_PX, cursor.y)
        val b = PointF(cursor.x + TWO_FINGER_INITIAL_SPREAD_PX, cursor.y)
        twoFingerPointA = a
        twoFingerPointB = b

        val service = accessibilityService ?: return
        val display = targetDisplay ?: return
        gestureInjector.twoFingerStart(
            service,
            display.displayId,
            a.x,
            a.y,
            b.x,
            b.y,
            onCancelledError("gesture_failed", "2本指スクロールの開始がキャンセルされました"),
        )
    }

    fun twoFingerScrollBy(dxPx: Float, dyPx: Float) {
        markCursorActivity()
        val a = twoFingerPointA ?: return
        val b = twoFingerPointB ?: return
        val display = targetDisplay ?: return
        val bounds = displaySessionManager.bounds(display)

        // 両点を必ず同じ量だけ動かす: 間隔が変化しないため、外部ディスプレイ側で
        // ピンチと解釈されることがない(常にスクロール)。境界では2点を
        // 独立にクランプすると間隔が崩れてしまうため、両点とも収まる範囲に
        // クランプした単一のデルタを両点へ適用する。
        val dx = clampDeltaForBothPoints(dxPx * config.pointerSpeed, a.x, b.x, bounds.left.toFloat(), bounds.right.toFloat())
        val dy = clampDeltaForBothPoints(dyPx * config.pointerSpeed, a.y, b.y, bounds.top.toFloat(), bounds.bottom.toFloat())
        a.x += dx
        a.y += dy
        b.x += dx
        b.y += dy

        val service = accessibilityService ?: return
        val moved = gestureInjector.twoFingerMove(
            service,
            display.displayId,
            a.x,
            a.y,
            b.x,
            b.y,
            ignoreOutcome,
        )
        if (!moved) {
            // pointerMove と同じ理由(§ pointerMove 参照): twoFingerScrollStart が届いて
            // いない/失敗している場合に無言で無視すると、仮想カーソルの見た目だけが
            // 動いて実際のスクロール注入が送られない。現在の2点でスクロールを張り直す。
            gestureInjector.twoFingerStart(
                service,
                display.displayId,
                a.x,
                a.y,
                b.x,
                b.y,
                onCancelledError("gesture_failed", "2本指スクロールの再開がキャンセルされました"),
            )
        }
    }

    fun twoFingerScrollEnd() {
        markCursorActivity()
        val a = twoFingerPointA ?: return
        val b = twoFingerPointB ?: return
        twoFingerPointA = null
        twoFingerPointB = null

        val service = accessibilityService ?: return
        val display = targetDisplay ?: return
        // pointerUp と同様、システムが既にキャンセル済み(ALREADY_ENDED)なら
        // 2本指ジェスチャーは実質的に終わっているので、そのまま成功扱いで無視する。
        gestureInjector.twoFingerEnd(
            service,
            display.displayId,
            a.x,
            a.y,
            b.x,
            b.y,
            onCancelledError("gesture_failed", "2本指スクロールの終了がキャンセルされました"),
        )
    }

    /**
     * 2本指の素早いスワイプ（フリック）。開始位置から [dxPx]/[dyPx] 方向へ
     * スケールした距離を一気に移動する単発ジェスチャーを dispatch する。
     */
    fun twoFingerSwipe(dxPx: Float, dyPx: Float) {
        markCursorActivity()
        val cursor = cursorState
            ?: throw DesktopModeException("session_not_active", "セッションが開始されていません")
        val display = targetDisplay ?: return
        val service = accessibilityService ?: return
        val bounds = displaySessionManager.bounds(display)

        val startA = PointF(cursor.x - TWO_FINGER_INITIAL_SPREAD_PX, cursor.y)
        val startB = PointF(cursor.x + TWO_FINGER_INITIAL_SPREAD_PX, cursor.y)

        val rawDx = dxPx * config.pointerSpeed * SWIPE_DISTANCE_SCALE
        val rawDy = dyPx * config.pointerSpeed * SWIPE_DISTANCE_SCALE

        val dx = clampDeltaForBothPoints(rawDx, startA.x, startB.x, bounds.left.toFloat(), bounds.right.toFloat())
        val dy = clampDeltaForBothPoints(rawDy, startA.y, startB.y, bounds.top.toFloat(), bounds.bottom.toFloat())

        gestureInjector.twoFingerSwipe(
            service,
            display.displayId,
            startA.x,
            startA.y,
            startB.x,
            startB.y,
            startA.x + dx,
            startA.y + dy,
            startB.x + dx,
            startB.y + dy,
            SWIPE_DURATION_MS,
            onCancelledError("gesture_failed", "2本指スワイプがキャンセルされました"),
        )
    }

    /**
     * `performGlobalAction` はディスプレイを指定できず、常に
     * `mTopFocusedDisplayId`(実機検証では常にスマホ本体側)に対して作用してしまう。
     * そのため呼び出すと「外部ディスプレイの操作のつもりが本体側のタッチパッド画面自体が
     * 戻る/閉じる」という事故につながる(R: back/recents がスマホ側に効いてしまう不具合)。
     * よって `performGlobalAction` は一切使わず、`setDisplayId` で明示的に外部ディスプレイを
     * 指定したジェスチャ注入のみで完結させる。
     */
    fun systemAction(action: String): Boolean {
        val service = accessibilityService ?: return false
        val display = targetDisplay ?: return false
        val bounds = displaySessionManager.bounds(display)
        val width = bounds.width().toFloat()
        val height = bounds.height().toFloat()

        if (action == "home") {
            return performHomeAction(service, display.displayId, width, height)
        }

        val accepted = injectNavigationGesture(service, display.displayId, action, width, height)
        Log.d(TAG, "systemAction action=$action display=${display.displayId} gestureAccepted=$accepted")
        return accepted
    }

    private fun performHomeAction(
        service: AccessibilityService,
        displayId: Int,
        width: Float,
        height: Float,
    ): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (now - lastHomeLaunchAtMs < HOME_LAUNCH_COOLDOWN_MS) {
            // OEM ホームランチャーが横向きの外部ディスプレイの表示に対応しておらず、
            // 短時間に連続起動すると再起動ループ(表示が乱れて点滅を繰り返す)を
            // 誘発することがあるため、連打は無視する。
            Log.d(TAG, "systemAction action=home display=$displayId ignored=cooldown")
            return true
        }
        lastHomeLaunchAtMs = now
        if (launchHomeOnDisplay(displayId)) {
            Log.d(TAG, "systemAction action=home display=$displayId launchedHome=true")
            return true
        }
        val accepted = injectNavigationGesture(service, displayId, "home", width, height)
        Log.d(TAG, "systemAction action=home display=$displayId fallbackGestureAccepted=$accepted")
        return accepted
    }

    private fun injectNavigationGesture(
        service: AccessibilityService,
        displayId: Int,
        action: String,
        width: Float,
        height: Float,
    ): Boolean {
        fun injectSwipe(
            startX: Float,
            startY: Float,
            endX: Float,
            endY: Float,
            durationMs: Long,
        ): Boolean = gestureInjector.swipe(
            service,
            displayId,
            startX,
            startY,
            endX,
            endY,
            durationMs,
            onCancelledError("system_gesture_failed", "System gesture was cancelled"),
        )

        return when (action) {
            // 戻るジェスチャは、画面端から内側へしっかりとスワイプしないと
            // タッチ/長押しとして誤認識されることがあるため、距離と速度を大きめにする。
            "back" -> injectSwipe(1f, height * 0.5f, width * 0.35f, height * 0.5f, 180L)
            "home" -> injectSwipe(width * 0.5f, height - 2f, width * 0.5f, height * 0.68f, 260L)
            else -> false
        }
    }

    /**
     * ホームとして起動するアプリを解決する。設定で明示指定されていればそれを使い
     * (例: OEM 標準ランチャーが横向きの外部ディスプレイに対応していない場合の回避策として
     * Nova Launcher 等を指定できる)、指定が無い/起動に失敗した場合はシステム標準に落ちる。
     *
     * 起動するアプリの宣言済み screenOrientation と実際のディスプレイの向きが
     * 一致しない場合(例: 縦長専用ランチャー×横長ディスプレイ、またはその逆)は、
     * 正しいアスペクト比を保つ領域を中央に確保し、余白に自然に黒帯が入るようにする。
     */
    private fun launchHomeOnDisplay(displayId: Int): Boolean {
        val display = displaySessionManager.findDisplay(displayId) ?: return false

        val overridePackage = config.externalHomePackage
        val overrideActivity = config.externalHomeActivity
        if (overridePackage != null && overrideActivity != null) {
            val info = resolveActivityInfo(overridePackage, overrideActivity)
            val bounds = computeLetterboxBounds(display, info)
            val launched = launchHomeIntent(displayId, bounds) {
                Intent(Intent.ACTION_MAIN)
                    .addCategory(Intent.CATEGORY_HOME)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .setClassName(overridePackage, overrideActivity)
            }
            if (launched) return true
            Log.w(TAG, "Configured home app $overridePackage/$overrideActivity failed, falling back to system default")
        }

        val baseIntent = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val activityInfo = appContext.packageManager
            .resolveActivity(baseIntent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo
            ?: return false
        val bounds = computeLetterboxBounds(display, activityInfo)
        return launchHomeIntent(displayId, bounds) {
            Intent(baseIntent).setClassName(activityInfo.packageName, activityInfo.name)
        }
    }

    private fun resolveActivityInfo(packageName: String, activityName: String): ActivityInfo? = try {
        appContext.packageManager.getActivityInfo(ComponentName(packageName, activityName), PackageManager.GET_META_DATA)
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    /**
     * ディスプレイの向きとアプリの宣言済み screenOrientation が食い違う場合に、
     * 正しいアスペクト比を保つレターボックス領域(黒帯付き)を計算する。
     * 向きが一致する、またはアプリが向きに追随する(UNSPECIFIED/SENSOR 系等、
     * ここで判定できない値)場合は null を返し、全画面を使う。
     *
     * 自アプリが直接起動するホーム/ランチャーにのみ適用する
     * (外部ランチャー経由でユーザーが開く他のアプリは対象外)。
     */
    private fun computeLetterboxBounds(display: Display, info: ActivityInfo?): Rect? {
        val full = displaySessionManager.bounds(display)
        val w = full.width()
        val h = full.height()
        val orientation = info?.screenOrientation ?: ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        return when {
            isEffectivelyPortrait(orientation) && w > h -> {
                val boxWidth = (h * 9f / 16f).toInt()
                val left = full.left + (w - boxWidth) / 2
                Rect(left, full.top, left + boxWidth, full.bottom)
            }
            isEffectivelyLandscape(orientation) && h > w -> {
                val boxHeight = (w * 9f / 16f).toInt()
                val top = full.top + (h - boxHeight) / 2
                Rect(full.left, top, full.right, top + boxHeight)
            }
            else -> null
        }
    }

    private fun isEffectivelyPortrait(orientation: Int) =
        orientation == ActivityInfo.SCREEN_ORIENTATION_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT

    private fun isEffectivelyLandscape(orientation: Int) =
        orientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE ||
            orientation == ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE

    private fun launchHomeIntent(
        displayId: Int,
        bounds: Rect?,
        buildIntent: () -> Intent?,
    ): Boolean {
        val homeIntent = buildIntent() ?: return false

        // displayId に対応する Display オブジェクトを取得し、
        // createDisplayContext でその display に紐づいた Context を作る。
        // これにより、この Context から起動された Activity と
        // そこから子として起動される Activity がすべて同じ display 上に
        // 留まるようになる(通常の appContext だとデフォルト display に行きがち)。
        val display = displaySessionManager.findDisplay(displayId)
            ?: return false.also {
                Log.w(TAG, "Cannot find display $displayId for home launch")
            }
        val displayContext = appContext.createDisplayContext(display)

        val builder = ActivityOptions.makeBasic()
            .setLaunchDisplayId(displayId)

        // 向きの不一致がある場合のみ領域を指定し、レターボックス(黒帯)を発生させる
        if (bounds != null) {
            builder.setLaunchBounds(bounds)
        }

        return try {
            displayContext.startActivity(homeIntent, builder.toBundle())
            true
        } catch (e: Exception) {
            lastError = "home_launch_failed: ${e.message}"
            Log.w(TAG, "Unable to launch home on display $displayId", e)
            false
        }
    }

    /** 外部ディスプレイのホームとして選択可能なランチャーアプリ一覧(CATEGORY_HOME を持つアプリ)。 */
    fun getHomeApps(): List<HomeAppInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val packageManager = appContext.packageManager

        /** システム専用のフォールバック ホーム(list: FallbackHome, SetupWizard など)。
         *  これらは特殊権限(DEVICE_POWER 等)を要求するため一般アプリから起動できない。
         *  ユーザーが誤って選択しないよう、選択肢から除外する。 */
        val systemOnlyHomePackages = setOf("com.android.settings")

        return packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                if (activityInfo.packageName in systemOnlyHomePackages) return@mapNotNull null
                HomeAppInfo(
                    packageName = activityInfo.packageName,
                    activityName = activityInfo.name,
                    label = resolveInfo.loadLabel(packageManager).toString(),
                    iconPng = loadIconBytes(packageManager, activityInfo),
                )
            }
            .distinctBy { it.packageName to it.activityName }
    }

    /**
     * インストール済みの起動可能アプリ一覧(CATEGORY_LAUNCHER を持つアプリ)。
     * タッチパッド画面の「アプリ一覧」ボタンから、外部ディスプレイへ任意のアプリを
     * 起動するための候補として使う。自アプリ自身は対象外とする。
     */
    fun getInstalledApps(): List<HomeAppInfo> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val packageManager = appContext.packageManager
        return packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
            .mapNotNull { resolveInfo ->
                val activityInfo = resolveInfo.activityInfo ?: return@mapNotNull null
                if (activityInfo.packageName == appContext.packageName) return@mapNotNull null
                HomeAppInfo(
                    packageName = activityInfo.packageName,
                    activityName = activityInfo.name,
                    label = resolveInfo.loadLabel(packageManager).toString(),
                    iconPng = loadIconBytes(packageManager, activityInfo),
                )
            }
            .distinctBy { it.packageName to it.activityName }
            .sortedBy { it.label.lowercase() }
    }

    /**
     * アプリアイコンを Drawable から PNG バイト列に変換する。
     * MethodChannel は byte[] を Uint8List として渡せる。
     */
    private fun loadIconBytes(packageManager: PackageManager, activityInfo: ActivityInfo): ByteArray? = try {
        val drawable = activityInfo.loadIcon(packageManager) ?: return null
        val bitmap = drawableToBitmap(drawable)
        ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        }
    } catch (e: Exception) {
        Log.w(TAG, "Unable to load icon for ${activityInfo.packageName}", e)
        null
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = drawable.intrinsicWidth.coerceAtLeast(1)
        val height = drawable.intrinsicHeight.coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    /**
     * 指定アプリを外部ディスプレイ(セッションの target display)上で起動する。
     * `launchHomeOnDisplay` と同じ「向き不一致ならレターボックス」ロジックを再利用する
     * (DRY: 唯一の違いは CATEGORY_HOME を付けないことと、対象が固定でなく任意アプリなこと)。
     *
     * 既にメインディスプレイなど別ディスプレイで起動済みのアプリがあった場合、
     * 既存タスクをクリアして必ず外部ディスプレイ上に新しいタスクを作る。
     */
    fun launchApp(packageName: String, activityName: String): Boolean {
        val display = targetDisplay
            ?: throw DesktopModeException("session_not_active", "セッションが開始されていません")
        val info = resolveActivityInfo(packageName, activityName)
        val bounds = computeLetterboxBounds(display, info)
        return launchHomeIntent(display.displayId, bounds) {
            Intent(Intent.ACTION_MAIN)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_MULTIPLE_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK,
                )
                .setClassName(packageName, activityName)
        }
    }

    fun updateConfig(
        pointerSpeed: Float,
        longPressDurationMs: Long,
        showCursor: Boolean,
        cursorIdleTimeoutMs: Long,
        externalHomePackage: String?,
        externalHomeActivity: String?,
        preferredDisplayModeId: Int? = null,
    ) {
        config = InjectorConfig(
            pointerSpeed,
            longPressDurationMs,
            showCursor,
            cursorIdleTimeoutMs,
            externalHomePackage,
            externalHomeActivity,
            preferredDisplayModeId,
        )
        if (!showCursor) {
            cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
            cursorIdleHidden = false
            overlayController.hide()
            return
        }
        val display = targetDisplay
        val cursor = cursorState
        // preferredDisplayModeId の変更を即座に反映するため、既に表示中でも
        // 再生成する(show() 内部で hide() してから作り直す、DRY)。
        if (display != null && cursor != null) {
            overlayController.show(
                accessibilityService ?: appContext,
                display,
                displaySessionManager.bounds(display),
                preferredDisplayModeId,
            )
            overlayController.move(cursor.x, cursor.y)
            markCursorActivity()
        }
    }

    fun getDiagnostics(): Diagnostics = Diagnostics(
        accessibilityEnabled = isAccessibilityEnabled(),
        displays = getDisplays(),
        targetDisplayId = targetDisplay?.displayId,
        displayBounds = targetDisplay?.let { displaySessionManager.bounds(it) },
        hasSecondaryDisplayFeature = displaySessionManager.hasSecondaryDisplaySupport(),
        overlayActive = overlayController.isActive,
        lastGestureResult = gestureInjector.lastGestureResult,
        lastError = lastError,
    )

    /** 常駐監視 Service など、Flutter エンジンと非同期な経路からのエラー記録用。 */
    fun recordError(code: String, message: String) {
        lastError = "$code: $message"
        emitEvent(mapOf("type" to "error", "code" to code, "message" to message))
    }

    private fun dispatchTap(durationMs: Long) {
        val service = accessibilityService
            ?: throw DesktopModeException("accessibility_disabled", "Accessibilityサービスが有効になっていません")
        val display = targetDisplay
        val cursor = cursorState
        if (display == null || cursor == null) {
            throw DesktopModeException("session_not_active", "セッションが開始されていません")
        }
        val accepted = gestureInjector.tap(
            service,
            display.displayId,
            cursor.x,
            cursor.y,
            durationMs,
            onCancelledError("gesture_failed", "ジェスチャがキャンセルされました"),
        )
        if (!accepted) {
            throw DesktopModeException("gesture_busy", "前のジェスチャが処理中です")
        }
    }

    private fun dispatchDrag(
        action: (AccessibilityService, Int, Float, Float) -> Boolean,
    ) {
        val service = accessibilityService
            ?: throw DesktopModeException("accessibility_disabled", "Accessibility service is not enabled")
        val display = targetDisplay
        val cursor = cursorState
        if (display == null || cursor == null) {
            throw DesktopModeException("session_not_active", "Session is not active")
        }
        val accepted = action(service, display.displayId, cursor.x, cursor.y)
        if (!accepted) {
            throw DesktopModeException("gesture_busy", "A gesture is already running")
        }
    }

    private fun emitEvent(event: Map<String, Any?>) {
        eventSink?.invoke(event)
    }

    /** ジェスチャが system 側でキャンセルされた場合にのみエラーイベントを送出するコールバックを作る(DRY)。 */
    private fun onCancelledError(code: String, message: String): (String) -> Unit = { outcome ->
        if (outcome == "cancelled") {
            emitEvent(mapOf("type" to "error", "code" to code, "message" to message))
        }
    }

    /** 連続 dispatch 中のキャンセルは正常な上書きとみなし、エラーイベントを送出しない。 */
    private val ignoreOutcome: (String) -> Unit = {}

    /**
     * Flutter 起動前に Accessibility Service が先に接続することがあるため、
     * shared_preferences(shared_preferences プラグインの保存先)から直接設定を読む。
     * AppSettings JSON が唯一の情報源であり、native 側は既定値へのフォールバックのみ持つ(DRY)。
     */
    private fun readConfigFromPrefs(): InjectorConfig {
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.desktop_mode.settings", null) ?: return InjectorConfig()
            val obj = JSONObject(json)
            InjectorConfig(
                pointerSpeed = obj.optDouble("pointerSpeed", 1.8).toFloat(),
                longPressDurationMs = obj.optLong("longPressDurationMs", 550L),
                showCursor = obj.optBoolean("showCursor", true),
                cursorIdleTimeoutMs = obj.optLong("cursorIdleTimeoutMs", 3000L),
                externalHomePackage = obj.optNullableString("externalHomePackage"),
                externalHomeActivity = obj.optNullableString("externalHomeActivity"),
                preferredDisplayModeId = obj.optNullableInt("preferredDisplayModeId"),
            )
        } catch (_: Throwable) {
            InjectorConfig()
        }
    }

    /**
     * `readConfigFromPrefs()` と同じ理由(Accessibility Service が Flutter エンジンより
     * 先に接続しうる)で、AppSettings JSON を直接読む。既定値は Flutter 側の
     * `AppSettings.autoStart` の既定値(true)と揃える。
     */
    private fun readAutoStartFromPrefs(): Boolean {
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.desktop_mode.settings", null) ?: return true
            JSONObject(json).optBoolean("autoStart", true)
        } catch (_: Throwable) {
            true
        }
    }
}

/**
 * [delta] を、[pointA]・[pointB] の両方が適用後も `[min, max]` に収まるようにクランプする。
 * 2点を独立にクランプすると一方だけ先に境界に達して間隔(≒ピンチかどうか)が
 * 崩れてしまうため、両点に同じデルタを適用する [DesktopModeController.twoFingerScrollBy] の
 * 不変条件(間隔一定)を維持するために使う。
 */
private fun clampDeltaForBothPoints(delta: Float, pointA: Float, pointB: Float, min: Float, max: Float): Float {
    val lo = minOf(pointA, pointB)
    val hi = maxOf(pointA, pointB)
    return delta.coerceIn(min - lo, max - hi)
}

/** JSON の null と欠落を区別せず Kotlin の null として扱う(org.json は JSON null を "null" 文字列にしがち)。 */
private fun JSONObject.optNullableString(key: String): String? =
    if (isNull(key)) null else optString(key).takeUnless { it.isEmpty() }

private fun JSONObject.optNullableInt(key: String): Int? =
    if (!has(key) || isNull(key)) null else optInt(key)
