import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 誤操作防止のロック画面(仕様 §8.7)。錠アイコンと進捗リングのみの最小構成。
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key, required this.holdProgress});

  final double holdProgress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
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
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                  const Icon(Icons.lock_outline, color: AppColors.foreground, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '長押しで解除',
              style: TextStyle(color: AppColors.foreground, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
