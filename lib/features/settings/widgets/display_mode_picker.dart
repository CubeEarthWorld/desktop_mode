import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/desktop_mode_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../models/display_mode_info.dart';

/// 接続先ディスプレイの解像度/リフレッシュレート選択。
/// 仮想ディスプレイを自作するのではなく、接続機器(HDMI/ワイヤレスディスプレイ等)が
/// 広告する既存のモードから選ぶ方式のため、選択肢は接続機器が対応する範囲に限られる。
/// 横長・縦長どちらの接続にもこだわらず、未選択時は端末の既定モードを使う。
///
/// 設定画面とホーム画面(外部ディスプレイタイルのタップ)の両方から使う共通ウィジェット。
class DisplayModePicker extends ConsumerWidget {
  const DisplayModePicker({
    super.key,
    required this.displayId,
    required this.selectedModeId,
    required this.onChanged,
  });

  final int displayId;
  final int? selectedModeId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(desktopModeApiProvider);
    return FutureBuilder<List<DisplayModeInfo>>(
      future: api.getSupportedDisplayModes(displayId),
      builder: (context, snapshot) {
        final modes = snapshot.data ?? const [];
        final validSelection = modes.any((m) => m.modeId == selectedModeId)
            ? selectedModeId
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('外部ディスプレイの解像度', style: TextStyle(color: AppColors.foreground)),
            const SizedBox(height: 4),
            const Text(
              '接続機器が対応する解像度/リフレッシュレートから選択します。'
              '未選択の場合は端末の既定モードのまま動作します。'
              'カーソル表示がオフの場合、この設定は反映されません。',
              style: TextStyle(color: AppColors.disabled, fontSize: 12),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (modes.length <= 1)
              const Text(
                'この接続機器は複数の解像度に対応していません。',
                style: TextStyle(color: AppColors.disabled, fontSize: 12),
              )
            else
              DropdownButton<int?>(
                value: validSelection,
                dropdownColor: const Color(0xFF0A0A0A),
                isExpanded: true,
                onChanged: onChanged,
                items: [
                  const DropdownMenuItem(value: null, child: Text('既定')),
                  for (final mode in modes)
                    DropdownMenuItem(
                      value: mode.modeId,
                      child: Text(
                        '${mode.widthPx}×${mode.heightPx} @ ${mode.refreshRate.toStringAsFixed(0)}Hz',
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
