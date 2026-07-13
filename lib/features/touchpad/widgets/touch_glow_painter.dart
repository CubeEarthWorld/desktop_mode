import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../touchpad_controller.dart';

/// 確定したクリックまたは長押しだけをフェード表示する。
class TouchGlowPainter extends StatelessWidget {
  const TouchGlowPainter({super.key, required this.fadingGlows});

  final List<FadingGlow> fadingGlows;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final glow in fadingGlows)
            _FadingGlowDot(key: ValueKey(glow.id), glow: glow),
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
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        // BoxShadow のぼかしは実機の描画エンジンによって描画されないことがあるため、
        // RadialGradient で疑似的な発光を表現する(shader ベースで描画バックエンド非依存)。
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.glowCenter,
                AppColors.glow.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
