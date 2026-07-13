import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/external_touchpad_channel.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// 設定は `AppSettings` → `SettingsRepository`(永続化)→ `updateConfig`(native 同期)の
/// 一方向フローで管理する(DRY: 変更経路は `update()` の1本のみ)。
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final settings = await ref.read(settingsRepositoryProvider).load();
    await _syncNative(settings);
    return settings;
  }

  Future<void> updateSettings(
    AppSettings Function(AppSettings current) transform,
  ) async {
    final current = state.value ?? const AppSettings();
    final next = transform(current);
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
    await _syncNative(next);
  }

  Future<void> _syncNative(AppSettings settings) => ref
      .read(externalTouchpadApiProvider)
      .updateConfig(
        pointerSpeed: settings.pointerSpeed,
        longPressDurationMs: settings.longPressDurationMs,
        showCursor: settings.showCursor,
        cursorIdleTimeoutMs: settings.cursorIdleTimeoutMs,
        externalHomePackage: settings.externalHomePackage,
        externalHomeActivity: settings.externalHomeActivity,
        preferredDisplayModeId: settings.preferredDisplayModeId,
        appWindowModes: settings.appWindowModes.map(
          (key, value) => MapEntry(key, value.name),
        ),
      );
}
