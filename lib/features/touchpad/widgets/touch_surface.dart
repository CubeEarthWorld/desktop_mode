import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../touchpad_controller.dart';
import 'center_crosshair.dart';
import 'touch_glow_painter.dart';

/// タッチパッド入力面。生の PointerEvent を [TouchpadController] に橋渡しするだけで、
/// ジェスチャの意味づけは一切行わない(認識はコントローラ配下の recognizer が担う)。
class TouchSurface extends StatelessWidget {
  const TouchSurface({
    super.key,
    required this.state,
    required this.controller,
  });

  final TouchpadState state;
  final TouchpadController controller;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => controller.handlePointerDown(
        event.pointer,
        event.localPosition,
        event.timeStamp,
      ),
      onPointerMove: (event) => controller.handlePointerMove(
        event.pointer,
        event.localPosition,
        event.timeStamp,
      ),
      onPointerUp: (event) => controller.handlePointerUp(
        event.pointer,
        event.localPosition,
        event.timeStamp,
      ),
      onPointerCancel: (event) => controller.handlePointerCancel(event.pointer),
      child: ColoredBox(
        color: AppColors.background,
        child: Stack(
          children: [
            const Center(child: CenterCrosshair()),
            TouchGlowPainter(fadingGlows: state.fadingGlows),
          ],
        ),
      ),
    );
  }
}
