import '../../models/app_window_mode.dart';

class AppSettings {
  const AppSettings({
    this.autoStart = true,
    this.residentMonitoring = false,
    this.showCursor = true,
    this.showTouchGlow = true,
    this.pointerSpeed = 1.8,
    this.longPressDurationMs = defaultLongPressDurationMs,
    this.cursorIdleTimeoutMs = 3000,
    this.preferredDisplayId,
    this.touchLockEnabled = false,
    this.touchLockIdleTimeoutSeconds = defaultTouchLockIdleTimeoutSeconds,
    this.minimizeBrightnessWhileLocked = false,
    this.oledProtection = false,
    this.externalHomePackage,
    this.externalHomeActivity,
    this.preferredDisplayModeId,
    this.appWindowModes = const {},
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    // 過去の既定値だけを新しい既定値へ移行する(ユーザーが明示的に変更した値は保持)。
    // v1: 550ms → v2: 1000ms → v3: 500ms
    var longPressDurationMs =
        json['longPressDurationMs'] as int? ?? defaultLongPressDurationMs;
    if (schemaVersion < 2 && longPressDurationMs == 550) {
      longPressDurationMs = 1000;
    }
    if (schemaVersion < 3 && longPressDurationMs == 1000) {
      longPressDurationMs = defaultLongPressDurationMs;
    }
    final rawWindowModes = json['appWindowModes'];
    final windowModes = <String, AppWindowMode>{};
    if (rawWindowModes is Map) {
      for (final entry in rawWindowModes.entries) {
        if (entry.key is! String || entry.value is! String) continue;
        final mode = AppWindowMode.fromWireName(entry.value as String);
        if (mode != AppWindowMode.auto) windowModes[entry.key as String] = mode;
      }
    }

    return AppSettings(
      autoStart: json['autoStart'] as bool? ?? true,
      residentMonitoring: json['residentMonitoring'] as bool? ?? false,
      showCursor: json['showCursor'] as bool? ?? true,
      showTouchGlow: json['showTouchGlow'] as bool? ?? true,
      pointerSpeed: (json['pointerSpeed'] as num?)?.toDouble() ?? 1.8,
      longPressDurationMs: longPressDurationMs.clamp(
        longPressDurationMinMs,
        longPressDurationMaxMs,
      ),
      cursorIdleTimeoutMs: json['cursorIdleTimeoutMs'] as int? ?? 3000,
      preferredDisplayId: json['preferredDisplayId'] as int?,
      touchLockEnabled: json['touchLockEnabled'] as bool? ?? false,
      touchLockIdleTimeoutSeconds: _touchLockIdleTimeoutFromJson(
        json['touchLockIdleTimeoutSeconds'],
      ),
      minimizeBrightnessWhileLocked:
          json['minimizeBrightnessWhileLocked'] as bool? ?? false,
      oledProtection: json['oledProtection'] as bool? ?? false,
      externalHomePackage: json['externalHomePackage'] as String?,
      externalHomeActivity: json['externalHomeActivity'] as String?,
      preferredDisplayModeId: json['preferredDisplayModeId'] as int?,
      appWindowModes: Map.unmodifiable(windowModes),
    );
  }

  static const currentSchemaVersion = 4;
  static const pointerSpeedMin = 0.5;
  static const pointerSpeedMax = 4.0;
  static const longPressDurationMinMs = 400;
  static const longPressDurationMaxMs = 1500;

  /// 長押し/ドラッグ開始の既定時間(0.5秒)。native 側の
  /// `InjectorConfig.longPressDurationMs` の既定値と揃える。
  static const defaultLongPressDurationMs = 500;
  static const cursorIdleTimeoutMinMs = 0;
  static const cursorIdleTimeoutMaxMs = 10000;
  static const defaultTouchLockIdleTimeoutSeconds = 30;
  static const touchLockIdleTimeoutOptionsSeconds = [5, 10, 30];

  final bool autoStart;
  final bool residentMonitoring;
  final bool showCursor;
  final bool showTouchGlow;
  final double pointerSpeed;
  final int longPressDurationMs;
  final int cursorIdleTimeoutMs;
  final int? preferredDisplayId;
  final bool touchLockEnabled;
  final int touchLockIdleTimeoutSeconds;
  final bool minimizeBrightnessWhileLocked;
  final bool oledProtection;
  final String? externalHomePackage;
  final String? externalHomeActivity;
  final int? preferredDisplayModeId;
  final Map<String, AppWindowMode> appWindowModes;

  AppWindowMode windowModeFor(String packageName, String activityName) =>
      appWindowModes['$packageName/$activityName'] ?? AppWindowMode.auto;

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'autoStart': autoStart,
    'residentMonitoring': residentMonitoring,
    'showCursor': showCursor,
    'showTouchGlow': showTouchGlow,
    'pointerSpeed': pointerSpeed,
    'longPressDurationMs': longPressDurationMs,
    'cursorIdleTimeoutMs': cursorIdleTimeoutMs,
    'preferredDisplayId': preferredDisplayId,
    'touchLockEnabled': touchLockEnabled,
    'touchLockIdleTimeoutSeconds': touchLockIdleTimeoutSeconds,
    'minimizeBrightnessWhileLocked': minimizeBrightnessWhileLocked,
    'oledProtection': oledProtection,
    'externalHomePackage': externalHomePackage,
    'externalHomeActivity': externalHomeActivity,
    'preferredDisplayModeId': preferredDisplayModeId,
    'appWindowModes': appWindowModes.map(
      (key, value) => MapEntry(key, value.name),
    ),
  };

  AppSettings copyWith({
    bool? autoStart,
    bool? residentMonitoring,
    bool? showCursor,
    bool? showTouchGlow,
    double? pointerSpeed,
    int? longPressDurationMs,
    int? cursorIdleTimeoutMs,
    int? preferredDisplayId,
    bool clearPreferredDisplayId = false,
    bool? touchLockEnabled,
    int? touchLockIdleTimeoutSeconds,
    bool? minimizeBrightnessWhileLocked,
    bool? oledProtection,
    String? externalHomePackage,
    String? externalHomeActivity,
    bool clearExternalHomeApp = false,
    int? preferredDisplayModeId,
    bool clearPreferredDisplayModeId = false,
    Map<String, AppWindowMode>? appWindowModes,
  }) => AppSettings(
    autoStart: autoStart ?? this.autoStart,
    residentMonitoring: residentMonitoring ?? this.residentMonitoring,
    showCursor: showCursor ?? this.showCursor,
    showTouchGlow: showTouchGlow ?? this.showTouchGlow,
    pointerSpeed: pointerSpeed ?? this.pointerSpeed,
    longPressDurationMs: longPressDurationMs ?? this.longPressDurationMs,
    cursorIdleTimeoutMs: cursorIdleTimeoutMs ?? this.cursorIdleTimeoutMs,
    preferredDisplayId: clearPreferredDisplayId
        ? null
        : (preferredDisplayId ?? this.preferredDisplayId),
    touchLockEnabled: touchLockEnabled ?? this.touchLockEnabled,
    touchLockIdleTimeoutSeconds:
        touchLockIdleTimeoutSeconds ?? this.touchLockIdleTimeoutSeconds,
    minimizeBrightnessWhileLocked:
        minimizeBrightnessWhileLocked ?? this.minimizeBrightnessWhileLocked,
    oledProtection: oledProtection ?? this.oledProtection,
    externalHomePackage: clearExternalHomeApp
        ? null
        : (externalHomePackage ?? this.externalHomePackage),
    externalHomeActivity: clearExternalHomeApp
        ? null
        : (externalHomeActivity ?? this.externalHomeActivity),
    preferredDisplayModeId: clearPreferredDisplayModeId
        ? null
        : (preferredDisplayModeId ?? this.preferredDisplayModeId),
    appWindowModes: appWindowModes ?? this.appWindowModes,
  );

  AppSettings withWindowMode(
    String packageName,
    String activityName,
    AppWindowMode mode,
  ) {
    final key = '$packageName/$activityName';
    final next = Map<String, AppWindowMode>.from(appWindowModes);
    if (mode == AppWindowMode.auto) {
      next.remove(key);
    } else {
      next[key] = mode;
    }
    return copyWith(appWindowModes: Map.unmodifiable(next));
  }
}

int _touchLockIdleTimeoutFromJson(Object? value) {
  final seconds = value is int
      ? value
      : AppSettings.defaultTouchLockIdleTimeoutSeconds;
  return AppSettings.touchLockIdleTimeoutOptionsSeconds.contains(seconds)
      ? seconds
      : AppSettings.defaultTouchLockIdleTimeoutSeconds;
}
