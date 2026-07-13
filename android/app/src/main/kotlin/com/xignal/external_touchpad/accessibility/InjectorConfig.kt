package com.xignal.external_touchpad.accessibility

/** native 側の可変設定。Flutter の `updateConfig` 呼び出しで更新される。 */
data class InjectorConfig(
    val pointerSpeed: Float = 1.8f,
    /** 長押し/ドラッグ開始の既定時間。Flutter 側 `AppSettings.defaultLongPressDurationMs` と揃える。 */
    val longPressDurationMs: Long = 500L,
    val showCursor: Boolean = true,
    /** カーソル操作が無くなってから外部ディスプレイのカーソルを非表示にするまでの時間。0 以下は非表示にしない。 */
    val cursorIdleTimeoutMs: Long = 3000L,
    /** 外部ディスプレイの「ホーム」として明示指定されたアプリ。null はシステム標準。 */
    val externalHomePackage: String? = null,
    val externalHomeActivity: String? = null,
    /** 接続先ディスプレイの [android.view.Display.Mode.getModeId]。null は端末の既定モード。 */
    val preferredDisplayModeId: Int? = null,
)
