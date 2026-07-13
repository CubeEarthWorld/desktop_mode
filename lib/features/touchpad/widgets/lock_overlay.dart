import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';

/// 誤操作防止のロック画面(仕様 §8.7)。錠アイコンと進捗リングのみの最小構成。
class LockOverlay extends StatelessWidget {
  const LockOverlay({
    super.key,
    required this.holdProgress,
    this.contentOffset = Offset.zero,
  });

  final double holdProgress;
  final Offset contentOffset;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Transform.translate(
          offset: contentOffset,
          child: Opacity(
            opacity: 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: holdProgress,
                        strokeWidth: 3,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accent,
                        ),
                      ),
                      const Icon(
                        Icons.lock_outline,
                        color: AppColors.foreground,
                        size: 28,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.unlockByLongPress,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
