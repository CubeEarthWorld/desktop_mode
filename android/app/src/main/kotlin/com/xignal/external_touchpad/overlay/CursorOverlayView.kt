package com.xignal.external_touchpad.overlay

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator

class CursorOverlayView(context: Context) : View(context) {
    private val density = context.resources.displayMetrics.density

    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f * density
        color = Color.argb(200, 158, 158, 158)
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(220, 224, 224, 224)
    }

    // ドラッグ中のカーソル。アプリのアクセント色(#448AFF)の塗り + 太めのリングで
    // 「掴んでいる」状態を通常時と明確に区別する。
    private val dragRingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * density
        color = Color.argb(230, 68, 138, 255)
    }
    private val dragFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = Color.argb(70, 68, 138, 255)
    }

    private val touchEffectPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val ringRadius = 12f * density
    private val dotRadius = 2f * density
    val preferredSizePx: Int = (80f * density).toInt().coerceAtLeast(80)

    private var dragging = false

    private val touchEffects = mutableListOf<TouchEffect>()
    private var nextEffectId = 0

    /** ドラッグ中はカーソルの見た目を「掴んでいる」デザインへ切り替える。 */
    fun setDragging(active: Boolean) {
        if (dragging == active) return
        dragging = active
        invalidate()
    }

    fun showTouchEffect() {
        val effect = TouchEffect(id = nextEffectId++)
        touchEffects.add(effect)

        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = TOUCH_EFFECT_DURATION_MS
            interpolator = AccelerateDecelerateInterpolator()
            addUpdateListener {
                effect.progress = it.animatedValue as Float
                invalidate()
            }
            addListener(
                object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        touchEffects.removeAll { it.id == effect.id }
                        invalidate()
                    }
                },
            )
            start()
        }
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        touchEffects.removeAll { it.progress >= 1f }

        val centerX = width / 2f
        val centerY = height / 2f
        for (effect in touchEffects) {
            drawTouchEffect(canvas, effect, centerX, centerY)
        }

        if (dragging) {
            canvas.drawCircle(centerX, centerY, ringRadius, dragFillPaint)
            canvas.drawCircle(centerX, centerY, ringRadius, dragRingPaint)
        } else {
            canvas.drawCircle(centerX, centerY, ringRadius, ringPaint)
        }
        canvas.drawCircle(centerX, centerY, dotRadius, dotPaint)
    }

    private fun drawTouchEffect(
        canvas: Canvas,
        effect: TouchEffect,
        centerX: Float,
        centerY: Float,
    ) {
        val radius = TOUCH_EFFECT_MAX_RADIUS_DP * density * effect.progress
        val alpha = ((1f - effect.progress) * TOUCH_EFFECT_MAX_ALPHA).toInt()
        touchEffectPaint.color = Color.argb(alpha, 180, 180, 180)
        canvas.drawCircle(centerX, centerY, radius, touchEffectPaint)
    }

    private data class TouchEffect(
        val id: Int,
        var progress: Float = 0f,
    )

    private companion object {
        const val TOUCH_EFFECT_DURATION_MS = 300L
        const val TOUCH_EFFECT_MAX_RADIUS_DP = 32f
        const val TOUCH_EFFECT_MAX_ALPHA = 180
    }
}
