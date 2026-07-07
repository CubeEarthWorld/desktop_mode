import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../touchpad_controller.dart';

/// 指ごとの円形発光(アクティブ + フェードアウト中)を描画する。
/// タッチ位置のフィードバックのみを目的とし、入力は一切受け取らない。
class TouchGlowPainter extends StatelessWidget {
  const TouchGlowPainter({super.key, required this.activeTouches, required this.fadingGlows});

  final Map<int, Offset> activeTouches;
  final List<FadingGlow> fadingGlows;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _GlowPainter(activePositions: activeTouches.values.toList()),
          ),
          for (final glow in fadingGlows) _FadingGlowDot(key: ValueKey(glow.id), glow: glow),
        ],
      ),
    );
  }
}

class _FadingGlowDot extends StatelessWidget {
  const _FadingGlowDot({super.key, required this.glow});

  final FadingGlow glow;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: glow.position.dx - AppDimens.touchGlowRadius,
      top: glow.position.dy - AppDimens.touchGlowRadius,
      width: AppDimens.touchGlowRadius * 2,
      height: AppDimens.touchGlowRadius * 2,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: AppDimens.touchGlowFadeOutMs),
        curve: Curves.easeOut,
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        // BoxShadow のぼかしは実機の描画エンジンによって描画されないことがあるため、
        // RadialGradient で疑似的な発光を表現する(shader ベースで描画バックエンド非依存)。
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [AppColors.glowCenter, AppColors.glow.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.activePositions});

  final List<Offset> activePositions;

  @override
  void paint(Canvas canvas, Size size) {
    // MaskFilter.blur は実機の描画バックエンドによって描画されないことがあるため、
    // RadialGradient シェーダーで発光を表現する(FadingGlow と同じ手法で統一)。
    for (final position in activePositions) {
      final rect = Rect.fromCircle(center: position, radius: AppDimens.touchGlowRadius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [AppColors.glowCenter, AppColors.glow.withValues(alpha: 0)],
        ).createShader(rect);
      canvas.drawCircle(position, AppDimens.touchGlowRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.activePositions != activePositions;
}
