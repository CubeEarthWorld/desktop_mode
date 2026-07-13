package com.xignal.external_touchpad

import android.graphics.Rect
import com.xignal.external_touchpad.display.DisplayInfo

enum class SessionStatus { IDLE, ACTIVE }

data class SessionState(
    val status: SessionStatus,
    val targetDisplayId: Int?,
    val overlayActive: Boolean,
)

/** 外部ディスプレイへ起動可能な Activity の表示情報。 */
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
    val inputPhase: String,
    val inputSessionId: Long?,
    val activeGestureId: Long?,
    val activeGestureKind: String?,
    val lastCancellationReason: String?,
    val launchBoundsWarning: String?,
)

/** Channel 経由で Flutter に伝える native 側エラー(§4.1 のエラーコードを code に格納する)。 */
class ExternalTouchpadException(val code: String, message: String) : Exception(message)
