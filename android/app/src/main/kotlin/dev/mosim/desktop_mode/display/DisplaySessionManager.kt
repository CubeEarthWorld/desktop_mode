package dev.mosim.desktop_mode.display

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.view.Display
import android.view.WindowManager

/** 外部ディスプレイ情報(native → Flutter、読み取り専用)。 */
data class DisplayInfo(
    val id: Int,
    val name: String,
    val widthPx: Int,
    val heightPx: Int,
    val densityDpi: Float,
    val isDefault: Boolean,
)

/**
 * 接続先ディスプレイが実際に対応している解像度/リフレッシュレートの組み合わせ
 * ([Display.getSupportedModes] より)。仮想ディスプレイを自作するのではなく、
 * 接続機器(HDMI/ワイヤレスディスプレイ等)が広告する既存のモードから選ぶ方式のため、
 * root/ADB 権限は不要な反面、選択肢は接続機器が対応する範囲に限られる。
 */
data class DisplayModeInfo(
    val modeId: Int,
    val widthPx: Int,
    val heightPx: Int,
    val refreshRate: Float,
)

interface DisplaySessionListener {
    fun onDisplayAdded(displayId: Int)
    fun onDisplayRemoved(displayId: Int)
    fun onDisplayChanged(displayId: Int)
}

/**
 * 外部ディスプレイの検出・境界取得・target 選択のみを担う。
 * カーソル座標やセッション状態(active/idle)は持たない(単一責任)。
 */
class DisplaySessionManager(private val appContext: Context) {
    private val displayManager =
        appContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private var listener: DisplaySessionListener? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {
            listener?.onDisplayAdded(displayId)
        }

        override fun onDisplayRemoved(displayId: Int) {
            listener?.onDisplayRemoved(displayId)
        }

        override fun onDisplayChanged(displayId: Int) {
            listener?.onDisplayChanged(displayId)
        }
    }

    fun start(listener: DisplaySessionListener) {
        this.listener = listener
        displayManager.registerDisplayListener(displayListener, null)
    }

    fun stop() {
        displayManager.unregisterDisplayListener(displayListener)
        listener = null
    }

    fun listDisplays(): List<DisplayInfo> = displayManager.displays.map { toInfo(it) }

    fun findDisplay(displayId: Int): Display? =
        displayManager.displays.firstOrNull { it.displayId == displayId }

    fun externalDisplays(): List<Display> {
        val presentationDisplays = displayManager
            .getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .filter { it.displayId != Display.DEFAULT_DISPLAY }
        return presentationDisplays.ifEmpty {
            displayManager.displays.filter { it.displayId != Display.DEFAULT_DISPLAY }
        }
    }

    fun bounds(display: Display): Rect = windowMetricsBounds(display)

    /** target 未指定時: 最大面積の外部ディスプレイを自動選択する。 */
    fun pickAutoTarget(): Display? =
        externalDisplays().maxByOrNull { display ->
            val b = windowMetricsBounds(display)
            b.width().toLong() * b.height().toLong()
        }

    fun hasSecondaryDisplaySupport(): Boolean =
        appContext.packageManager.hasSystemFeature(
            PackageManager.FEATURE_ACTIVITIES_ON_SECONDARY_DISPLAYS,
        )

    /** 指定ディスプレイが対応する解像度/リフレッシュレートの一覧(設定画面の選択肢用)。 */
    fun getSupportedModes(displayId: Int): List<DisplayModeInfo> {
        val display = findDisplay(displayId) ?: return emptyList()
        return display.supportedModes.map {
            DisplayModeInfo(
                modeId = it.modeId,
                widthPx = it.physicalWidth,
                heightPx = it.physicalHeight,
                refreshRate = it.refreshRate,
            )
        }
    }

    private fun windowMetricsBounds(display: Display): Rect {
        // currentWindowMetrics は「呼び出し元の現在のウィンドウ」の寸法を返すため、
        // ウィンドウを持たない createDisplayContext だけでは display 本来のサイズが取れず、
        // 内蔵画面のサイズにフォールバックしてしまう(ミラーリング判定の誤りの原因になる)。
        // maximumWindowMetrics は指定 display 上でアプリが取りうる最大サイズを返すため、
        // こちらを display 全体のサイズとして扱う。
        val windowContext = appContext
            .createDisplayContext(display)
            .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION, null)
        val windowManager = windowContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return windowManager.maximumWindowMetrics.bounds
    }

    private fun toInfo(display: Display): DisplayInfo {
        val displayContext = appContext.createDisplayContext(display)
        val metrics = displayContext.resources.displayMetrics
        val bounds = windowMetricsBounds(display)
        return DisplayInfo(
            id = display.displayId,
            name = display.name ?: "Display ${display.displayId}",
            widthPx = bounds.width(),
            heightPx = bounds.height(),
            densityDpi = metrics.densityDpi.toFloat(),
            isDefault = display.displayId == Display.DEFAULT_DISPLAY,
        )
    }
}
