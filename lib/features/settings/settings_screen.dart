import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_status_provider.dart';
import '../../core/platform/desktop_mode_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../models/display_info.dart';
import '../../models/home_app_info.dart';
import 'widgets/display_mode_picker.dart';

/// 設定画面。§4.1 AppSettings の全項目 + 操作方法の掲示 + 診断画面への導線。
/// 変更は即保存・即 native 同期(保存ボタンを持たない、アクション最小の原則)。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final externalDisplays = ref.watch(
      appStatusProvider.select((s) => s.externalDisplays),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('設定の読み込みに失敗しました: $error')),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            _SectionLabel('起動'),
            _ToggleRow(
              label: '自動起動',
              description: '外部ディスプレイ接続時に自動でタッチパッド画面を開く',
              value: settings.autoStart,
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(autoStart: v)),
            ),
            _ToggleRow(
              label: '常駐監視',
              description: 'アプリを閉じていても外部ディスプレイ接続を監視する',
              value: settings.residentMonitoring,
              onChanged: (v) async {
                final api = ref.read(desktopModeApiProvider);
                final accepted = await api.setResidentMonitoring(v);
                await notifier.updateSettings(
                  (s) => s.copyWith(residentMonitoring: accepted && v),
                );
              },
            ),
            const Divider(color: AppColors.divider, height: AppDimens.spacingLarge * 2),
            _SectionLabel('表示'),
            _ToggleRow(
              label: '外部カーソル表示',
              description: '外部ディスプレイ上に仮想カーソルを表示する',
              value: settings.showCursor,
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(showCursor: v)),
            ),
            _ToggleRow(
              label: 'タッチ発光表示',
              description: '本体画面のタッチ位置をぼんやり光らせる',
              value: settings.showTouchGlow,
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(showTouchGlow: v)),
            ),
            const Divider(color: AppColors.divider, height: AppDimens.spacingLarge * 2),
            _SectionLabel('操作'),
            _SliderRow(
              label: 'ポインター速度',
              value: settings.pointerSpeed,
              min: AppSettings.pointerSpeedMin,
              max: AppSettings.pointerSpeedMax,
              displayValue: settings.pointerSpeed.toStringAsFixed(1),
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(pointerSpeed: v)),
            ),
            _SliderRow(
              label: '長押し/ドラッグ開始時間',
              value: settings.longPressDurationMs.toDouble(),
              min: AppSettings.longPressDurationMinMs.toDouble(),
              max: AppSettings.longPressDurationMaxMs.toDouble(),
              displayValue: '${settings.longPressDurationMs}ms',
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(longPressDurationMs: v.round())),
            ),
            _SliderRow(
              label: 'カーソル自動非表示時間',
              value: settings.cursorIdleTimeoutMs.toDouble(),
              min: AppSettings.cursorIdleTimeoutMinMs.toDouble(),
              max: AppSettings.cursorIdleTimeoutMaxMs.toDouble(),
              displayValue: _cursorIdleLabel(settings.cursorIdleTimeoutMs),
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(cursorIdleTimeoutMs: v.round())),
            ),
            if (externalDisplays.length > 1) ...[
              const SizedBox(height: AppDimens.spacingMedium),
              _DisplayPicker(
                displays: externalDisplays,
                selectedId: settings.preferredDisplayId,
                onChanged: (id) => notifier.updateSettings(
                  (s) => id == null
                      ? s.copyWith(clearPreferredDisplayId: true)
                      : s.copyWith(preferredDisplayId: id),
                ),
              ),
            ],
            const SizedBox(height: AppDimens.spacingMedium),
            _HomeAppPicker(
              selectedPackage: settings.externalHomePackage,
              onChanged: (app) => notifier.updateSettings(
                (s) => app == null
                    ? s.copyWith(clearExternalHomeApp: true)
                    : s.copyWith(
                        externalHomePackage: app.packageName,
                        externalHomeActivity: app.activityName,
                      ),
              ),
            ),
            if (externalDisplays.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spacingMedium),
              DisplayModePicker(
                displayId: settings.preferredDisplayId ?? externalDisplays.first.id,
                selectedModeId: settings.preferredDisplayModeId,
                onChanged: (modeId) => notifier.updateSettings(
                  (s) => modeId == null
                      ? s.copyWith(clearPreferredDisplayModeId: true)
                      : s.copyWith(preferredDisplayModeId: modeId),
                ),
              ),
            ],
            const Divider(color: AppColors.divider, height: AppDimens.spacingLarge * 2),
            _SectionLabel('誤操作防止・画面保護'),
            _ToggleRow(
              label: 'タッチロック',
              description: '30秒無操作でロックし、2秒長押しで解除する',
              value: settings.touchLockEnabled,
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(touchLockEnabled: v)),
            ),
            _ToggleRow(
              label: '有機ELディスプレイの保護',
              description: '数分ごとにUI位置をわずかにずらす',
              value: settings.oledProtection,
              onChanged: (v) => notifier.updateSettings((s) => s.copyWith(oledProtection: v)),
            ),
            const Divider(color: AppColors.divider, height: AppDimens.spacingLarge * 2),
            const _SectionLabel('使い方'),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
              child: Text(
                '移動: 1本指で動かすとカーソルが移動します\n'
                '\n'
                'クリック: 1本指でタッチして、動かさずに素早く離すとクリック\n'
                '\n'
                '長押し: 1本指を動かさずにしばらく押さえてから、動かさずに離す'
                '(Android のマウスに右クリックは無いため、右クリックの代わりに'
                'この長押し操作を使います)\n'
                '\n'
                'ドラッグ: 1本指を動かさずにしばらく(長押し開始時間)押さえたあと、'
                'そのまま指を離さずに動かすとドラッグ開始。指を離すとドラッグ終了です\n'
                '\n'
                'スワイプ: 2本指を同時に動かすと、外部ディスプレイ側へスワイプ/'
                'スクロールとして転送されます。2点は常に同じ量だけ動くため'
                'ピンチにはなりません\n'
                '\n'
                '下部ナビ「戻る」: 外部ディスプレイへ画面端からのスワイプを送ります。'
                '外部ディスプレイ側のアプリ/ランチャーがジェスチャーナビゲーションの'
                '編集を認識していない場合、反応しないことがあります(Android にディスプレイを'
                '指定して「戻る」を送る公式手段が無いための制約です)\n'
                '\n'
                '下部ナビ「ホーム」: 設定したホームアプリ(未設定ならシステム標準)を'
                '外部ディスプレイで起動します\n'
                '\n'
                '下部ナビ「アプリ一覧」: インストール済みアプリの一覧を開き、'
                '選択したアプリを外部ディスプレイで起動します',
                style: TextStyle(color: AppColors.foreground, height: 1.6, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppDimens.spacingMedium),
            OutlinedButton(
              onPressed: () => context.push('/diagnostics'),
              child: const Text('診断画面を開く'),
            ),
          ],
        ),
      ),
    );
  }
}

String _cursorIdleLabel(int ms) {
  if (ms <= 0) return 'OFF';
  if (ms < 1000) return '${ms}ms';
  return '${(ms / 1000).toStringAsFixed(1)}秒';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.spacingSmall),
    child: Text(
      text,
      style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: AppColors.foreground)),
      subtitle: Text(description, style: const TextStyle(color: AppColors.disabled, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.foreground)),
            Text(displayValue, style: const TextStyle(color: AppColors.accent)),
          ],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}

/// 外部ディスプレイの「ホーム」で起動するアプリの選択(例: Nova Launcher)。
/// OEM 標準ランチャーが横向きの外部ディスプレイの表示に対応していない場合の回避策として、
/// 明示的に別のランチャーを選べるようにする。
class _HomeAppPicker extends ConsumerWidget {
  const _HomeAppPicker({required this.selectedPackage, required this.onChanged});

  final String? selectedPackage;
  final ValueChanged<HomeAppInfo?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(desktopModeApiProvider);
    return FutureBuilder<List<HomeAppInfo>>(
      future: api.getHomeApps(),
      builder: (context, snapshot) {
        final apps = snapshot.data ?? const [];
        final validSelection = apps.any((a) => a.packageName == selectedPackage)
            ? selectedPackage
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('外部ディスプレイのホームアプリ', style: TextStyle(color: AppColors.foreground)),
            const SizedBox(height: 4),
            const Text(
              'ホームボタンや戻る操作でホームを開く際に起動するアプリ。'
              '標準ランチャーが横画面に対応していない場合、別のランチャーを指定できます。',
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
            else
              DropdownButton<String?>(
                value: validSelection,
                dropdownColor: const Color(0xFF0A0A0A),
                isExpanded: true,
                onChanged: (packageName) {
                  HomeAppInfo? app;
                  for (final candidate in apps) {
                    if (candidate.packageName == packageName) {
                      app = candidate;
                      break;
                    }
                  }
                  onChanged(app);
                },
                items: [
                  const DropdownMenuItem(value: null, child: Text('システム標準')),
                  for (final app in apps)
                    DropdownMenuItem(value: app.packageName, child: Text(app.label)),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _DisplayPicker extends StatelessWidget {
  const _DisplayPicker({
    required this.displays,
    required this.selectedId,
    required this.onChanged,
  });

  final List<DisplayInfo> displays;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('対象ディスプレイ', style: TextStyle(color: AppColors.foreground)),
        const SizedBox(height: AppDimens.spacingSmall),
        DropdownButton<int?>(
          value: selectedId,
          dropdownColor: const Color(0xFF0A0A0A),
          isExpanded: true,
          onChanged: onChanged,
          items: [
            const DropdownMenuItem(value: null, child: Text('自動(最大の外部ディスプレイ)')),
            for (final display in displays)
              DropdownMenuItem(value: display.id, child: Text(display.name)),
          ],
        ),
      ],
    );
  }
}
