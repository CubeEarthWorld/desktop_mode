import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';

/// タッチパッド領域中央の十字(仕様 R12)。
/// 外部ディスプレイ上のカーソル初期位置(ディスプレイ中央)との対応を直感化する。
class CenterCrosshair extends StatelessWidget {
  const CenterCrosshair({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size.square(AppDimens.crosshairSize),
        painter: _CrosshairPainter(),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  // divider色(#242424)は黒背景とのコントラストが低すぎて実機でほぼ視認できないため、
  // 通常UI色(foreground)を使う。
  final _paint = Paint()
    ..color = AppColors.foreground
    ..strokeWidth = AppDimens.crosshairStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      _paint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
