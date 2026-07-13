import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_status_provider.dart';
import '../../core/platform/external_touchpad_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.settingsLoadFailed('$error'))),
        data: (settings) => ListView(
          padding: const EdgeInsets.all(AppDimens.screenPadding),
          children: [
            _SectionLabel(l10n.sectionStartup),
            _ToggleRow(
              label: l10n.autoStartLabel,
              description: l10n.autoStartDescription,
              value: settings.autoStart,
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(autoStart: v)),
            ),
            _ToggleRow(
              label: l10n.residentMonitoringLabel,
              description: l10n.residentMonitoringDescription,
              value: settings.residentMonitoring,
              onChanged: (v) async {
                final api = ref.read(externalTouchpadApiProvider);
                final accepted = await api.setResidentMonitoring(v);
                await notifier.updateSettings(
                  (s) => s.copyWith(residentMonitoring: accepted && v),
                );
              },
            ),
            const _SectionDivider(),
            _SectionLabel(l10n.sectionDisplay),
            _ToggleRow(
              label: l10n.showCursorLabel,
              description: l10n.showCursorDescription,
              value: settings.showCursor,
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(showCursor: v)),
            ),
            _ToggleRow(
              label: l10n.touchGlowLabel,
              description: l10n.touchGlowDescription,
              value: settings.showTouchGlow,
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(showTouchGlow: v)),
            ),
            const _SectionDivider(),
            _SectionLabel(l10n.sectionInput),
            _SliderRow(
              label: l10n.pointerSpeedLabel,
              value: settings.pointerSpeed,
              min: AppSettings.pointerSpeedMin,
              max: AppSettings.pointerSpeedMax,
              displayValue: settings.pointerSpeed.toStringAsFixed(1),
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(pointerSpeed: v)),
            ),
            _SliderRow(
              label: l10n.longPressDurationLabel,
              value: settings.longPressDurationMs.toDouble(),
              min: AppSettings.longPressDurationMinMs.toDouble(),
              max: AppSettings.longPressDurationMaxMs.toDouble(),
              displayValue: '${settings.longPressDurationMs}ms',
              onChanged: (v) => notifier.updateSettings(
                (s) => s.copyWith(longPressDurationMs: v.round()),
              ),
            ),
            _SliderRow(
              label: l10n.cursorIdleTimeoutLabel,
              value: settings.cursorIdleTimeoutMs.toDouble(),
              min: AppSettings.cursorIdleTimeoutMinMs.toDouble(),
              max: AppSettings.cursorIdleTimeoutMaxMs.toDouble(),
              displayValue: _cursorIdleLabel(
                l10n,
                settings.cursorIdleTimeoutMs,
              ),
              onChanged: (v) => notifier.updateSettings(
                (s) => s.copyWith(cursorIdleTimeoutMs: v.round()),
              ),
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
                displayId:
                    settings.preferredDisplayId ?? externalDisplays.first.id,
                selectedModeId: settings.preferredDisplayModeId,
                onChanged: (modeId) => notifier.updateSettings(
                  (s) => modeId == null
                      ? s.copyWith(clearPreferredDisplayModeId: true)
                      : s.copyWith(preferredDisplayModeId: modeId),
                ),
              ),
            ],
            const _SectionDivider(),
            _SectionLabel(l10n.sectionProtection),
            _ToggleRow(
              label: l10n.touchLockLabel,
              description: l10n.touchLockDescription,
              value: settings.touchLockEnabled,
              onChanged: (v) => notifier.updateSettings(
                (s) => s.copyWith(touchLockEnabled: v),
              ),
            ),
            _TouchLockTimeoutRow(
              value: settings.touchLockIdleTimeoutSeconds,
              onChanged: (seconds) => notifier.updateSettings(
                (s) => s.copyWith(touchLockIdleTimeoutSeconds: seconds),
              ),
            ),
            _ToggleRow(
              label: l10n.minimizeBrightnessWhileLockedLabel,
              description: l10n.minimizeBrightnessWhileLockedDescription,
              value: settings.minimizeBrightnessWhileLocked,
              onChanged: (v) => notifier.updateSettings(
                (s) => s.copyWith(minimizeBrightnessWhileLocked: v),
              ),
            ),
            _ToggleRow(
              label: l10n.oledProtectionLabel,
              description: l10n.oledProtectionDescription,
              value: settings.oledProtection,
              onChanged: (v) =>
                  notifier.updateSettings((s) => s.copyWith(oledProtection: v)),
            ),
            const _SectionDivider(),
            _SectionLabel(l10n.sectionHowTo),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spacingSmall,
              ),
              child: Text(
                l10n.howToText,
                style: const TextStyle(
                  color: AppColors.foreground,
                  height: 1.6,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spacingMedium),
            OutlinedButton(
              onPressed: () => context.push('/diagnostics'),
              child: Text(l10n.openDiagnostics),
            ),
            const _SectionDivider(),
            _SectionLabel(l10n.sectionAbout),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code, color: AppColors.accent),
              title: Text(
                l10n.openSourceLicenses,
                style: const TextStyle(color: AppColors.foreground),
              ),
              subtitle: Text(
                l10n.openSourceLicensesDescription,
                style: const TextStyle(color: AppColors.disabled, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
              ),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
              ),
            ),
            const _SectionDivider(),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l10n.resetSettingsButton),
                onPressed: () => _confirmResetSettings(context, notifier, l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 確認ダイアログを挟んでから設定を既定値へ戻す(誤操作防止)。
Future<void> _confirmResetSettings(
  BuildContext context,
  SettingsNotifier notifier,
  AppLocalizations l10n,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.resetSettingsConfirmTitle),
      content: Text(l10n.resetSettingsConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.resetSettingsCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.resetSettingsConfirmAction),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await notifier.resetToDefaults();
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.resetSettingsDone)));
  }
}

String _cursorIdleLabel(AppLocalizations l10n, int ms) {
  if (ms <= 0) return l10n.cursorIdleOff;
  if (ms < 1000) return '${ms}ms';
  return l10n.secondsValue((ms / 1000).toStringAsFixed(1));
}

/// セクション間の区切り線。全セクションで同じ見た目を共有する(DRY)。
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    color: AppColors.divider,
    height: AppDimens.spacingLarge * 2,
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.spacingSmall),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
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
      subtitle: Text(
        description,
        style: const TextStyle(color: AppColors.disabled, fontSize: 12),
      ),
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

class _TouchLockTimeoutRow extends StatelessWidget {
  const _TouchLockTimeoutRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingSmall),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.touchLockTimeoutLabel,
              style: const TextStyle(color: AppColors.foreground),
            ),
          ),
          const SizedBox(width: AppDimens.spacingMedium),
          DropdownButton<int>(
            value: value,
            dropdownColor: AppColors.surfaceElevated,
            onChanged: (seconds) {
              if (seconds != null) onChanged(seconds);
            },
            items: [
              for (final seconds
                  in AppSettings.touchLockIdleTimeoutOptionsSeconds)
                DropdownMenuItem(
                  value: seconds,
                  child: Text(l10n.secondsValue('$seconds')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 外部ディスプレイの「ホーム」で起動するアプリの選択(例: Nova Launcher)。
/// OEM 標準ランチャーが横向きの外部ディスプレイの表示に対応していない場合の回避策として、
/// 明示的に別のランチャーを選べるようにする。
class _HomeAppPicker extends ConsumerWidget {
  const _HomeAppPicker({
    required this.selectedPackage,
    required this.onChanged,
  });

  final String? selectedPackage;
  final ValueChanged<HomeAppInfo?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(externalTouchpadApiProvider);
    final l10n = context.l10n;
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
            Text(
              l10n.homeAppLabel,
              style: const TextStyle(color: AppColors.foreground),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.homeAppDescription,
              style: const TextStyle(color: AppColors.disabled, fontSize: 12),
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
                dropdownColor: AppColors.surfaceElevated,
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
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.systemDefault),
                  ),
                  for (final app in apps)
                    DropdownMenuItem(
                      value: app.packageName,
                      child: Text(app.label),
                    ),
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.targetDisplayLabel,
          style: const TextStyle(color: AppColors.foreground),
        ),
        const SizedBox(height: AppDimens.spacingSmall),
        DropdownButton<int?>(
          value: selectedId,
          dropdownColor: AppColors.surfaceElevated,
          isExpanded: true,
          onChanged: onChanged,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.targetDisplayAuto)),
            for (final display in displays)
              DropdownMenuItem(value: display.id, child: Text(display.name)),
          ],
        ),
      ],
    );
  }
}
