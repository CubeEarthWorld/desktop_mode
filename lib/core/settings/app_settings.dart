/// アプリ設定(不変、copyWith、shared_preferences に JSON 保存)。
/// デフォルト値の定義はこのコンストラクタ既定値の1箇所のみ(DRY)。
class AppSettings {
  const AppSettings({
    this.autoStart = true,
    this.residentMonitoring = false,
    this.showCursor = true,
    this.showTouchGlow = true,
    this.pointerSpeed = 1.8,
    // 長押しドラッグ開始までの待ち時間を短縮。実機で550msは長すぎて
    // ユーザーが待てずに動かしてカーソル移動になってしまうことがあったため、
    // 450msを既定値とする。
    this.longPressDurationMs = 450,
    this.cursorIdleTimeoutMs = 3000,
    this.preferredDisplayId,
    this.touchLockEnabled = false,
    this.oledProtection = false,
    this.showGestureDebug = false,
    this.externalHomePackage,
    this.externalHomeActivity,
    this.preferredDisplayModeId,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    autoStart: json['autoStart'] as bool? ?? true,
    residentMonitoring: json['residentMonitoring'] as bool? ?? false,
    showCursor: json['showCursor'] as bool? ?? true,
    showTouchGlow: json['showTouchGlow'] as bool? ?? true,
    pointerSpeed: (json['pointerSpeed'] as num?)?.toDouble() ?? 1.8,
    longPressDurationMs: json['longPressDurationMs'] as int? ?? 450,
    cursorIdleTimeoutMs: json['cursorIdleTimeoutMs'] as int? ?? 3000,
    preferredDisplayId: json['preferredDisplayId'] as int?,
    touchLockEnabled: json['touchLockEnabled'] as bool? ?? false,
    oledProtection: json['oledProtection'] as bool? ?? false,
    showGestureDebug: json['showGestureDebug'] as bool? ?? false,
    externalHomePackage: json['externalHomePackage'] as String?,
    externalHomeActivity: json['externalHomeActivity'] as String?,
    preferredDisplayModeId: json['preferredDisplayModeId'] as int?,
  );

  static const pointerSpeedMin = 0.5;
  static const pointerSpeedMax = 4.0;
  static const longPressDurationMinMs = 400;
  static const longPressDurationMaxMs = 800;
  static const cursorIdleTimeoutMinMs = 0;
  static const cursorIdleTimeoutMaxMs = 10000;

  final bool autoStart;
  final bool residentMonitoring;
  final bool showCursor;
  final bool showTouchGlow;
  final double pointerSpeed;
  final int longPressDurationMs;
  final int cursorIdleTimeoutMs;
  final int? preferredDisplayId;
  final bool touchLockEnabled;
  final bool oledProtection;
  final bool showGestureDebug;

  /// 外部ディスプレイでホームとして起動するアプリの明示指定。
  /// null は「システム標準のホームアプリを使う」を意味する(§4.1 の一方向フロー)。
  final String? externalHomePackage;
  final String? externalHomeActivity;

  /// 接続先ディスプレイに要求する解像度/リフレッシュレート
  /// ([android.view.Display.Mode] の modeId)。null は端末の既定モード。
  final int? preferredDisplayModeId;

  Map<String, Object?> toJson() => {
    'autoStart': autoStart,
    'residentMonitoring': residentMonitoring,
    'showCursor': showCursor,
    'showTouchGlow': showTouchGlow,
    'pointerSpeed': pointerSpeed,
    'longPressDurationMs': longPressDurationMs,
    'cursorIdleTimeoutMs': cursorIdleTimeoutMs,
    'preferredDisplayId': preferredDisplayId,
    'touchLockEnabled': touchLockEnabled,
    'oledProtection': oledProtection,
    'showGestureDebug': showGestureDebug,
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
    int? longPressDurationMs,
    int? cursorIdleTimeoutMs,
    int? preferredDisplayId,
    bool clearPreferredDisplayId = false,
    bool? touchLockEnabled,
    bool? oledProtection,
    bool? showGestureDebug,
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
    longPressDurationMs: longPressDurationMs ?? this.longPressDurationMs,
    cursorIdleTimeoutMs: cursorIdleTimeoutMs ?? this.cursorIdleTimeoutMs,
    preferredDisplayId: clearPreferredDisplayId
        ? null
        : (preferredDisplayId ?? this.preferredDisplayId),
    touchLockEnabled: touchLockEnabled ?? this.touchLockEnabled,
    oledProtection: oledProtection ?? this.oledProtection,
    showGestureDebug: showGestureDebug ?? this.showGestureDebug,
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
