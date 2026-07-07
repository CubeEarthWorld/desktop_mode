package dev.mosim.desktop_mode

import android.graphics.Rect
import dev.mosim.desktop_mode.display.DisplayInfo

enum class SessionStatus { IDLE, ACTIVE }

data class SessionState(
    val status: SessionStatus,
    val targetDisplayId: Int?,
    val overlayActive: Boolean,
)

/** 外部ディスプレイの「ホーム」として選択可能なランチャーアプリ(CATEGORY_HOME を持つアプリ)。 */
data class HomeAppInfo(
    val packageName: String,
    val activityName: String,
    val label: String,
    val iconPng: ByteArray? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as HomeAppInfo
        return packageName == other.packageName &&
            activityName == other.activityName &&
            label == other.label &&
            iconPng.contentEquals(other.iconPng)
    }

    override fun hashCode(): Int {
        var result = packageName.hashCode()
        result = 31 * result + activityName.hashCode()
        result = 31 * result + label.hashCode()
        result = 31 * result + (iconPng?.contentHashCode() ?: 0)
        return result
    }
}

data class Diagnostics(
    val accessibilityEnabled: Boolean,
    val displays: List<DisplayInfo>,
    val targetDisplayId: Int?,
    val displayBounds: Rect?,
    val hasSecondaryDisplayFeature: Boolean,
    val overlayActive: Boolean,
    val lastGestureResult: String,
    val lastError: String?,
)

/** Channel 経由で Flutter に伝える native 側エラー(§4.1 のエラーコードを code に格納する)。 */
class DesktopModeException(val code: String, message: String) : Exception(message)
