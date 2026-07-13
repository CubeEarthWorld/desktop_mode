package com.xignal.external_touchpad

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import com.xignal.external_touchpad.accessibility.CursorState
import com.xignal.external_touchpad.accessibility.ContinuousGestureKind
import com.xignal.external_touchpad.accessibility.GestureAck
import com.xignal.external_touchpad.accessibility.GestureInjector
import com.xignal.external_touchpad.accessibility.InjectorConfig
import com.xignal.external_touchpad.accessibility.RemoteInputAccessibilityService
import com.xignal.external_touchpad.accessibility.SoftKeyboardCoordinator
import com.xignal.external_touchpad.apps.AppCatalog
import com.xignal.external_touchpad.apps.ExternalAppLauncher
import com.xignal.external_touchpad.display.DisplayInfo
import com.xignal.external_touchpad.display.DisplayModeInfo
import com.xignal.external_touchpad.display.DisplaySessionListener
import com.xignal.external_touchpad.display.DisplaySessionManager
import com.xignal.external_touchpad.navigation.ExternalDisplayNavigator
import com.xignal.external_touchpad.overlay.CursorOverlayController
import org.json.JSONObject

private const val TAG = "ExternalTouchpadController"

/**
 * アプリ全体の唯一の調停者。認識(Flutter)/注入(GestureInjector)/
 * 座標管理(CursorState)/表示(CursorOverlayController)/検出(DisplaySessionManager)を
 * それぞれ単機能のクラスに閉じ込め、本クラスは接続と状態遷移のみを行う(SRP)。
 */
class ExternalTouchpadController private constructor(private val appContext: Context) :
    DisplaySessionListener {

    companion object {
        @Volatile private var instance: ExternalTouchpadController? = null

        fun getInstance(context: Context): ExternalTouchpadController =
            instance ?: synchronized(this) {
                instance ?: ExternalTouchpadController(context.applicationContext).also { instance = it }
            }
    }

    /** ExternalTouchpadChannel が onListen/onCancel で差し替える送出口。 */
    var eventSink: ((Map<String, Any?>) -> Unit)? = null

    private val displaySessionManager = DisplaySessionManager(appContext)
    private val gestureInjector = GestureInjector()
    private val overlayController = CursorOverlayController()
    private val appCatalog = AppCatalog(appContext)

    private var accessibilityService: AccessibilityService? = null
    private var cursorState: CursorState? = null
    private var targetDisplay: Display? = null
    private var status: SessionStatus = SessionStatus.IDLE
    private var config: InjectorConfig = readConfigFromPrefs()
    private var lastError: String? = null
    private val appLauncher = ExternalAppLauncher(
        context = appContext,
        displays = displaySessionManager,
        appCatalog = appCatalog,
        onLaunchFailure = { lastError = it },
        onWarning = ::recordError,
    ).apply {
        updateConfig(
            externalHomePackage = config.externalHomePackage,
            externalHomeActivity = config.externalHomeActivity,
        )
    }
    private val softKeyboardCoordinator = SoftKeyboardCoordinator(
        context = appContext,
        onError = ::recordError,
    )
    private val displayNavigator = ExternalDisplayNavigator(
        gestureInjector = gestureInjector,
        launchHome = appLauncher::launchHome,
        onGestureOutcome = onCancelledError(
            "system_gesture_failed",
            "System gesture was cancelled",
        ),
    )
    private var continuousInputId: Long? = null
    private var continuousInputKind: ContinuousGestureKind? = null
    private var continuousContactX: Float = 0f
    private var continuousContactY: Float = 0f
    private var lastContinuousInputId: Long = 0L
    private var flutterInputPhase: String = "idle"
    private var flutterInputSessionId: Long? = null
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
        // (結果としてホームアプリの起動も行われず、外部ディスプレイが
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
        if (!readAutoStartFromPrefs() || accessibilityService == null) return
        val display = displaySessionManager.pickAutoTarget() ?: return
        if (display.displayId in claimedDisplays) return
        claimedDisplays += display.displayId
        activateSession(display)
    }

    // ---- Accessibility 接続状態(仕様 R10: push 通知) ----

    fun attachAccessibilityService(service: AccessibilityService) {
        accessibilityService = service
        softKeyboardCoordinator.attach(service)
        config = readConfigFromPrefs()
        updateAppLauncherConfig()
        emitEvent(mapOf("type" to "accessibilityStateChanged", "enabled" to true))
        tryAutoClaimConnectedDisplay()
    }

    fun detachAccessibilityService(service: AccessibilityService) {
        if (accessibilityService === service) {
            softKeyboardCoordinator.detach(service)
            gestureInjector.reset("accessibility_disconnected")
            accessibilityService = null
            continuousInputId = null
            continuousInputKind = null
            overlayController.setDragging(false)
        }
        // onUnbind can run while Android is merely rebinding the already-enabled
        // service. Report the persisted setting on the next main-loop turn so a
        // debug app launch is not mistaken for a revoked permission.
        cursorIdleHandler.post {
            emitEvent(
                mapOf(
                    "type" to "accessibilityStateChanged",
                    "enabled" to isAccessibilityEnabled(),
                ),
            )
        }
    }

    fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        softKeyboardCoordinator.onAccessibilityEvent(event)
        accessibilityService?.let { appLauncher.onAccessibilityEvent(event, it) }
    }

    /** True when the user has enabled this service, including a short rebind window. */
    fun isAccessibilityEnabled(): Boolean =
        accessibilityService != null || isAccessibilityServiceConfigured()

    private fun isAccessibilityServiceConfigured(): Boolean {
        val manager = appContext.getSystemService(AccessibilityManager::class.java) ?: return false
        val expected = ComponentName(appContext, RemoteInputAccessibilityService::class.java)
        return manager
            .getEnabledAccessibilityServiceList(android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { info ->
                val serviceInfo = info.resolveInfo?.serviceInfo
                serviceInfo?.packageName == expected.packageName && serviceInfo.name == expected.className
            }
    }

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

    // ---- ExternalTouchpadChannel から呼ばれる公開 API ----

    fun getDisplays(): List<DisplayInfo> = displaySessionManager.listDisplays()

    /**
     * アプリが前面に戻った際、外部ディスプレイが接続されていてセッションが未開始なら
     * 自動的にセッションを開始しホームアプリを起動する。常駐監視 Service からの起動や
     * プロセス復帰時の取りこぼしを防ぐためのフォールバック入口。
     */
    fun ensureSessionAndHome() {
        if (status == SessionStatus.ACTIVE) return
        if (accessibilityService == null) return
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
            ?: throw ExternalTouchpadException("display_not_found", "外部ディスプレイが見つかりません")

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
        softKeyboardCoordinator.onSessionStarted(display.displayId)

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
        displayNavigator.markHomeLaunched()
        val homeLaunched = appLauncher.launchHome(display.displayId)
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
        softKeyboardCoordinator.onSessionStopped()
        gestureInjector.reset("session_stopped", releasePointer = true)
        continuousInputId = null
        continuousInputKind = null
        appLauncher.clearPendingVerification()
        overlayController.hide()
        targetDisplay = null
        cursorState = null
        status = SessionStatus.IDLE
    }

    /** タッチパッド上のソフトキーボード以外を触ったとき、現在の標準 IME を閉じる。 */
    fun dismissSoftKeyboard() = softKeyboardCoordinator.dismiss()

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
            ?: throw ExternalTouchpadException("session_not_active", "セッションが開始されていません")
        cursor.moveBy(dxPx * config.pointerSpeed, dyPx * config.pointerSpeed)
        overlayController.move(cursor.x, cursor.y)
        markCursorActivity()
    }

    fun commitPointerAction(
        type: String,
        showFeedback: Boolean,
        onFinished: (GestureAck) -> Unit,
    ) {
        val service = accessibilityService
        val display = targetDisplay
        val cursor = cursorState
        if (service == null || display == null || cursor == null) {
            onFinished(GestureAck.FAILED)
            return
        }
        val durationMs = when (type) {
            "click" -> 50L
            "longPress" -> config.longPressDurationMs
            else -> {
                onFinished(GestureAck.FAILED)
                return
            }
        }
        softKeyboardCoordinator.prepareForPointerAction(
            displayId = display.displayId,
            x = cursor.x,
            y = cursor.y,
        )
        val ack = gestureInjector.tap(
            service = service,
            displayId = display.displayId,
            x = cursor.x,
            y = cursor.y,
            durationMs = durationMs,
            onOutcome = onCancelledError("gesture_failed", "$type gesture was cancelled"),
            onFinished = onFinished,
        )
        if (ack != GestureAck.ACCEPTED) {
            onFinished(ack)
            return
        }
        if (showFeedback) {
            overlayController.showTouchEffect(cursor.x, cursor.y)
        }
        markCursorActivity()
    }

    fun beginContinuousGesture(id: Long, kind: ContinuousGestureKind): GestureAck {
        val service = accessibilityService ?: return GestureAck.FAILED
        val display = targetDisplay ?: return GestureAck.FAILED
        val cursor = cursorState ?: return GestureAck.FAILED
        var ack = gestureInjector.beginContinuous(
            service = service,
            displayId = display.displayId,
            id = id,
            kind = kind,
            x = cursor.x,
            y = cursor.y,
            onOutcome = onCancelledError("gesture_failed", "${kind.wireName} gesture was cancelled"),
        )
        if (ack == GestureAck.FAILED) {
            // A new physical touch session cannot legitimately overlap the old
            // one. Recover from an OEM callback that never arrived (or a nav
            // gesture racing this input) instead of dropping the whole scroll.
            gestureInjector.reset("superseded_by_gesture_$id")
            ack = gestureInjector.beginContinuous(
                service = service,
                displayId = display.displayId,
                id = id,
                kind = kind,
                x = cursor.x,
                y = cursor.y,
                onOutcome = onCancelledError(
                    "gesture_failed",
                    "${kind.wireName} gesture was cancelled",
                ),
            )
        }
        if (ack == GestureAck.ACCEPTED) {
            continuousInputId = id
            continuousInputKind = kind
            continuousContactX = cursor.x
            continuousContactY = cursor.y
            if (kind == ContinuousGestureKind.DRAG) {
                overlayController.setDragging(true)
            }
            markCursorActivity()
        }
        return ack
    }

    fun updateContinuousGesture(id: Long, dxPx: Float, dyPx: Float): GestureAck {
        if (continuousInputId != id) {
            return if (id <= lastContinuousInputId) GestureAck.ALREADY_ENDED else GestureAck.STALE
        }
        val kind = continuousInputKind ?: return GestureAck.STALE
        val display = targetDisplay ?: return GestureAck.FAILED
        val cursor = cursorState ?: return GestureAck.FAILED
        val scaledDx = dxPx * config.pointerSpeed
        val scaledDy = dyPx * config.pointerSpeed

        when (kind) {
            ContinuousGestureKind.DRAG -> {
                cursor.moveBy(scaledDx, scaledDy)
                continuousContactX = cursor.x
                continuousContactY = cursor.y
                overlayController.move(cursor.x, cursor.y)
            }
            ContinuousGestureKind.SCROLL -> {
                val bounds = displaySessionManager.usableBounds(display)
                continuousContactX = (continuousContactX + scaledDx).coerceIn(
                    bounds.left.toFloat(),
                    (bounds.right - 1).coerceAtLeast(bounds.left).toFloat(),
                )
                continuousContactY = (continuousContactY + scaledDy).coerceIn(
                    bounds.top.toFloat(),
                    (bounds.bottom - 1).coerceAtLeast(bounds.top).toFloat(),
                )
            }
        }
        markCursorActivity()
        return gestureInjector.updateContinuous(id, continuousContactX, continuousContactY)
    }

    fun endContinuousGesture(
        id: Long,
        cancelled: Boolean,
        onFinished: (GestureAck) -> Unit,
    ) {
        if (continuousInputId == id) {
            if (continuousInputKind == ContinuousGestureKind.DRAG) {
                overlayController.setDragging(false)
            }
            continuousInputId = null
            continuousInputKind = null
            lastContinuousInputId = maxOf(lastContinuousInputId, id)
        }
        gestureInjector.endContinuous(id, cancelled, onFinished)
        markCursorActivity()
    }

    fun updateInputDiagnostics(phase: String, sessionId: Long?) {
        flutterInputPhase = phase
        flutterInputSessionId = sessionId
    }

    fun systemAction(action: String): Boolean {
        val service = accessibilityService ?: return false
        val display = targetDisplay ?: return false
        val bounds = displaySessionManager.bounds(display)
        return displayNavigator.perform(
            service = service,
            displayId = display.displayId,
            action = action,
            width = bounds.width().toFloat(),
            height = bounds.height().toFloat(),
        )
    }

    fun getHomeApps(): List<HomeAppInfo> = appCatalog.getHomeApps()

    fun getInstalledApps(): List<HomeAppInfo> = appCatalog.getInstalledApps()

    fun getAppIcon(packageName: String, activityName: String): ByteArray? =
        appCatalog.getAppIcon(packageName, activityName)

    fun launchApp(packageName: String, activityName: String): Boolean {
        val display = targetDisplay
            ?: throw ExternalTouchpadException(
                "session_not_active",
                "セッションが開始されていません",
            )
        return appLauncher.launchApp(display, packageName, activityName)
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
            pointerSpeed = pointerSpeed,
            longPressDurationMs = longPressDurationMs,
            showCursor = showCursor,
            cursorIdleTimeoutMs = cursorIdleTimeoutMs,
            externalHomePackage = externalHomePackage,
            externalHomeActivity = externalHomeActivity,
            preferredDisplayModeId = preferredDisplayModeId,
        )
        updateAppLauncherConfig()
        if (!showCursor) {
            cursorIdleHandler.removeCallbacks(cursorIdleRunnable)
            cursorIdleHidden = false
            overlayController.hide()
            return
        }
        val display = targetDisplay
        val cursor = cursorState
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

    private fun updateAppLauncherConfig() {
        appLauncher.updateConfig(
            externalHomePackage = config.externalHomePackage,
            externalHomeActivity = config.externalHomeActivity,
        )
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
        inputPhase = flutterInputPhase,
        inputSessionId = flutterInputSessionId,
        activeGestureId = gestureInjector.activeGestureId,
        activeGestureKind = gestureInjector.activeGestureKind,
        lastCancellationReason = gestureInjector.lastCancellationReason,
        launchBoundsWarning = appLauncher.launchBoundsWarning,
    )

    /** 常駐監視 Service など、Flutter エンジンと非同期な経路からのエラー記録用。 */
    fun recordError(code: String, message: String) {
        lastError = "$code: $message"
        emitEvent(mapOf("type" to "error", "code" to code, "message" to message))
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

    /**
     * Flutter 起動前に Accessibility Service が先に接続することがあるため、
     * shared_preferences(shared_preferences プラグインの保存先)から直接設定を読む。
     * AppSettings JSON が唯一の情報源であり、native 側は既定値へのフォールバックのみ持つ(DRY)。
     */
    private fun readConfigFromPrefs(): InjectorConfig {
        return try {
            val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val json = prefs.getString("flutter.external_touchpad.settings", null) ?: return InjectorConfig()
            val obj = JSONObject(json)
            // 過去の既定値だけを新しい既定値へ移行する(Flutter 側 AppSettings.fromJson と同じ規則)。
            // v1: 550ms → v2: 1000ms → v3: 500ms
            val schemaVersion = obj.optInt("schemaVersion", 1)
            var longPressDurationMs = obj.optLong("longPressDurationMs", 500L)
            if (schemaVersion < 2 && longPressDurationMs == 550L) {
                longPressDurationMs = 1000L
            }
            if (schemaVersion < 3 && longPressDurationMs == 1000L) {
                longPressDurationMs = 500L
            }
            InjectorConfig(
                pointerSpeed = obj.optDouble("pointerSpeed", 1.8).toFloat(),
                longPressDurationMs = longPressDurationMs,
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
            val json = prefs.getString("flutter.external_touchpad.settings", null) ?: return true
            JSONObject(json).optBoolean("autoStart", true)
        } catch (_: Throwable) {
            true
        }
    }
}

/** JSON の null と欠落を区別せず Kotlin の null として扱う(org.json は JSON null を "null" 文字列にしがち)。 */
private fun JSONObject.optNullableString(key: String): String? =
    if (isNull(key)) null else optString(key).takeUnless { it.isEmpty() }

private fun JSONObject.optNullableInt(key: String): Int? =
    if (!has(key) || isNull(key)) null else optInt(key)
