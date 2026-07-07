import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_status_provider.dart';
import '../../core/platform/desktop_mode_channel.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../models/session_state.dart';
import '../settings/widgets/display_mode_picker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(appStatusProvider);
    final api = ref.read(desktopModeApiProvider);

    // セッションのライフサイクルは Android ネイティブ側が所有する(仕様変更)。
    // このホーム画面が起動した時点で既にセッションがアクティブ(例: 常駐監視の
    // 通知をタップして起動した、または外部ディスプレイが既に接続済みだった)なら、
    // ユーザーが何も操作せずともタッチパッド画面へ追従する。
    ref.listen(appStatusProvider.select((s) => s.sessionState.status), (previous, next) {
      if (next == SessionStatus.active) {
        context.go('/touchpad');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Desktop Touchpad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: '診断',
            onPressed: () => context.push('/diagnostics'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusTile(
              icon: status.accessibilityEnabled
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              label: 'Accessibility',
              value: status.accessibilityEnabled ? '有効' : '無効（操作に必要です）',
              highlighted: !status.accessibilityEnabled,
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            if (!status.accessibilityEnabled)
              FilledButton(
                onPressed: () => api.openAccessibilitySettings(),
                child: const Text('Accessibility設定を開く'),
              ),
            const SizedBox(height: AppDimens.spacingLarge),
            InkWell(
              onTap: status.hasExternalDisplay
                  ? () => _showDisplayModeSheet(context, ref, status)
                  : null,
              child: _StatusTile(
                icon: status.hasExternalDisplay
                    ? Icons.desktop_windows_outlined
                    : Icons.desktop_access_disabled_outlined,
                label: '外部ディスプレイ',
                value: status.hasExternalDisplay
                    ? '${status.externalDisplays.map((d) => '${d.name} (${d.widthPx}×${d.heightPx})').join(', ')}(タップして解像度を変更)'
                    : '未接続',
                highlighted: false,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: status.canOpenTouchpad
                  ? () async {
                      // ネイティブ側の自動クレーム(接続イベント駆動)が何らかの理由で
                      // 先に発火していない場合の明示的なユーザー操作。
                      // 既にアクティブなら startSession は no-op(冪等)。
                      await api.startSession();
                      if (context.mounted) context.push('/touchpad');
                    }
                  : null,
              child: const Text('タッチパッドを開く'),
            ),
            const SizedBox(height: AppDimens.spacingLarge),
            const Text(
              'サイドロード時に Accessibility 設定がグレーアウトする場合は、'
              'アプリ情報から「制限付き設定を許可」を有効にしてください。',
              style: TextStyle(color: AppColors.disabled, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 外部ディスプレイの解像度/リフレッシュレートを選ぶモーダルシート。
/// 設定画面の同項目と同じ `DisplayModePicker` を再利用する(DRY)。
void _showDisplayModeSheet(BuildContext context, WidgetRef ref, AppStatus status) {
  final settings = ref.read(settingsProvider).value;
  final notifier = ref.read(settingsProvider.notifier);
  final displayId = settings?.preferredDisplayId ?? status.externalDisplays.first.id;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF0A0A0A),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(AppDimens.screenPadding),
      child: DisplayModePicker(
        displayId: displayId,
        selectedModeId: settings?.preferredDisplayModeId,
        onChanged: (modeId) {
          notifier.updateSettings(
            (s) => modeId == null
                ? s.copyWith(clearPreferredDisplayModeId: true)
                : s.copyWith(preferredDisplayModeId: modeId),
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.accent : AppColors.foreground;
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppDimens.spacingSmall),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.disabled, fontSize: 12),
              ),
              Text(value, style: TextStyle(color: color, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
