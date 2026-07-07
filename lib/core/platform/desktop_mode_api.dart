import '../../models/desktop_mode_event.dart';
import '../../models/diagnostics_info.dart';
import '../../models/display_info.dart';
import '../../models/display_mode_info.dart';
import '../../models/home_app_info.dart';
import '../../models/session_state.dart';

/// Flutter 側が依存する抽象(DIP)。MethodChannel 実装はこれの一実装に過ぎず、
/// テストやプレビューではフェイク実装に差し替えられる。
abstract interface class DesktopModeApi {
  Future<List<DisplayInfo>> getDisplays();

  /// 指定ディスプレイが対応する解像度/リフレッシュレートの一覧。
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId);
  Future<SessionState> getSessionState();
  Future<SessionState> startSession({int? displayId});
  Future<void> stopSession();
  Future<void> moveCursor(double dx, double dy);
  Future<void> leftClick();

  /// 指を動かさずに長押しして離した場合の長押し操作(Android のマウスに
  /// 右クリックが無いため、右クリックの代替として現在カーソル位置に長押しタップを送る)。
  Future<void> longPress();
  Future<void> showTouchEffectAtCursor();
  Future<void> pointerDown();
  Future<void> pointerMove(double dx, double dy);
  Future<void> pointerUp();

  /// 2本指スクロールの開始。常に2点を同じ量だけ動かして転送するため、
  /// 外部ディスプレイ側でピンチと解釈されることはない。
  Future<void> twoFingerScrollStart();

  /// 2本指スクロールの今フレーム分のデルタ(2点とも同じ量だけ動かす)。
  Future<void> twoFingerScrollBy(double dx, double dy);
  Future<void> twoFingerScrollEnd();

  /// 2本指の素早いスワイプ（フリック）。
  /// [dx]/[dy] はスワイプ方向を表す。
  Future<void> twoFingerSwipe(double dx, double dy);

  Future<bool> systemAction(String action);
  Future<void> updateConfig({
    required double pointerSpeed,
    required int longPressDurationMs,
    required bool showCursor,
    required int cursorIdleTimeoutMs,
    String? externalHomePackage,
    String? externalHomeActivity,
    int? preferredDisplayModeId,
  });
  Future<DiagnosticsInfo> getDiagnostics();
  Future<bool> isAccessibilityEnabled();
  Future<void> openAccessibilitySettings();
  Future<bool> setResidentMonitoring(bool enabled);

  /// 外部ディスプレイのホームとして選択可能なランチャーアプリ一覧
  /// (CATEGORY_HOME を持つアプリ)。
  Future<List<HomeAppInfo>> getHomeApps();

  /// インストール済みの起動可能アプリ一覧(CATEGORY_LAUNCHER を持つアプリ)。
  /// タッチパッド画面の「アプリ一覧」ボタンから使う。
  Future<List<HomeAppInfo>> getInstalledApps();

  /// 指定アプリを外部ディスプレイ上で起動する。
  Future<bool> launchApp(String packageName, String activityName);

  Stream<DesktopModeEvent> get events;
}
