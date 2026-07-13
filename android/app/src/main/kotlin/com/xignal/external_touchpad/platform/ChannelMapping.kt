package com.xignal.external_touchpad.platform

import android.graphics.Rect
import com.xignal.external_touchpad.Diagnostics
import com.xignal.external_touchpad.HomeAppInfo
import com.xignal.external_touchpad.SessionState
import com.xignal.external_touchpad.display.DisplayInfo
import com.xignal.external_touchpad.display.DisplayModeInfo

/**
 * Channel の wire format(Map)への変換のみを担う(ドメインモデルはシリアライズを知らない)。
 */

fun DisplayInfo.toMap(): Map<String, Any?> = mapOf(
    "id" to id,
    "name" to name,
    "widthPx" to widthPx,
    "heightPx" to heightPx,
    "densityDpi" to densityDpi,
    "isDefault" to isDefault,
)

fun SessionState.toMap(): Map<String, Any?> = mapOf(
    "status" to status.name.lowercase(),
    "targetDisplayId" to targetDisplayId,
    "overlayActive" to overlayActive,
)

fun DisplayModeInfo.toMap(): Map<String, Any?> = mapOf(
    "modeId" to modeId,
    "widthPx" to widthPx,
    "heightPx" to heightPx,
    "refreshRate" to refreshRate,
)

fun HomeAppInfo.toMap(): Map<String, Any?> = mapOf(
    "packageName" to packageName,
    "activityName" to activityName,
    "label" to label,
    "iconPng" to iconPng,
)

fun Rect.toMap(): Map<String, Any?> = mapOf(
    "left" to left,
    "top" to top,
    "right" to right,
    "bottom" to bottom,
)

fun Diagnostics.toMap(): Map<String, Any?> = mapOf(
    "accessibilityEnabled" to accessibilityEnabled,
    "displays" to displays.map { it.toMap() },
    "targetDisplayId" to targetDisplayId,
    "displayBounds" to displayBounds?.toMap(),
    "hasSecondaryDisplayFeature" to hasSecondaryDisplayFeature,
    "overlayActive" to overlayActive,
    "lastGestureResult" to lastGestureResult,
    "lastError" to lastError,
    "inputPhase" to inputPhase,
    "inputSessionId" to inputSessionId,
    "activeGestureId" to activeGestureId,
    "activeGestureKind" to activeGestureKind,
    "lastCancellationReason" to lastCancellationReason,
    "launchBoundsWarning" to launchBoundsWarning,
)
