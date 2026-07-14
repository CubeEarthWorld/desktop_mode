class AppSettings {
  const AppSettings({
    this.autoStart = false,
    this.residentMonitoring = false,
    this.showCursor = true,
    this.showTouchGlow = true,
    this.pointerSpeed = 1.8,
    this.dragSensitivity = 0,
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
    return AppSettings(
      autoStart: json['autoStart'] as bool? ?? false,
      residentMonitoring: json['residentMonitoring'] as bool? ?? false,
      showCursor: json['showCursor'] as bool? ?? true,
      showTouchGlow: json['showTouchGlow'] as bool? ?? true,
      pointerSpeed: (json['pointerSpeed'] as num?)?.toDouble() ?? 1.8,
      dragSensitivity: ((json['dragSensitivity'] as num?)?.toInt() ?? 0).clamp(
        dragSensitivityMin,
        dragSensitivityMax,
      ),
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
    );
  }

  static const currentSchemaVersion = 5;
  static const pointerSpeedMin = 0.5;
  static const pointerSpeedMax = 4.0;
  static const dragSensitivityMin = -2;
  static const dragSensitivityMax = 2;

  /// ドラッグ中だけに掛かる感度の倍率。0(既定)は 1.0 倍で他の操作と挙動を変えない。
  static double dragSensitivityMultiplier(int level) => 1.0 + level * 0.25;
  static const longPressDurationMinMs = 400;
  static const longPressDurationMaxMs = 1500;

  /// 長押し/ドラッグ開始の既定時間(0.5秒)。native 側の
  /// `InjectorConfig.longPressDurationMs` の既定値と揃える。
  static const defaultLongPressDurationMs = 500;
  static const cursorIdleTimeoutMinMs = 0;
  static const cursorIdleTimeoutMaxMs = 10000;
  static const defaultTouchLockIdleTimeoutSeconds = 30;
  static const touchLockIdleTimeoutOptionsSeconds = <int>[5, 10, 30];

  final bool autoStart;
  final bool residentMonitoring;
  final bool showCursor;
  final bool showTouchGlow;
  final double pointerSpeed;
  final int dragSensitivity;
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
  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'autoStart': autoStart,
    'residentMonitoring': residentMonitoring,
    'showCursor': showCursor,
    'showTouchGlow': showTouchGlow,
    'pointerSpeed': pointerSpeed,
    'dragSensitivity': dragSensitivity,
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
  };

  AppSettings copyWith({
    bool? autoStart,
    bool? residentMonitoring,
    bool? showCursor,
    bool? showTouchGlow,
    double? pointerSpeed,
    int? dragSensitivity,
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
  }) => AppSettings(
    autoStart: autoStart ?? this.autoStart,
    residentMonitoring: residentMonitoring ?? this.residentMonitoring,
    showCursor: showCursor ?? this.showCursor,
    showTouchGlow: showTouchGlow ?? this.showTouchGlow,
    pointerSpeed: pointerSpeed ?? this.pointerSpeed,
    dragSensitivity: dragSensitivity ?? this.dragSensitivity,
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
  );
}

int _touchLockIdleTimeoutFromJson(Object? value) {
  final seconds = value is int
      ? value
      : AppSettings.defaultTouchLockIdleTimeoutSeconds;
  return AppSettings.touchLockIdleTimeoutOptionsSeconds.contains(seconds)
      ? seconds
      : AppSettings.defaultTouchLockIdleTimeoutSeconds;
}
