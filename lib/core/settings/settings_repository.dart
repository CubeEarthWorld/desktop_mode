import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// 唯一の永続化キー。native 側 (`DesktopModeController.readConfigFromPrefs`) も
/// 同じキーで shared_preferences を読むため、キー名の変更はここと native の両方に影響する。
const settingsPreferenceKey = 'desktop_mode.settings';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

/// AppSettings の永続化のみを担う。
class SettingsRepository {
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsPreferenceKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsPreferenceKey, jsonEncode(settings.toJson()));
  }
}
