import 'dart:typed_data';

import '../../models/external_touchpad_event.dart';
import '../../models/diagnostics_info.dart';
import '../../models/display_info.dart';
import '../../models/display_mode_info.dart';
import '../../models/home_app_info.dart';
import '../../models/session_state.dart';

enum PointerActionType { click, longPress }

enum RemoteGestureKind { drag, scroll }

enum GestureAck {
  accepted,
  queued,
  alreadyEnded,
  stale,
  cancelled,
  failed;

  static GestureAck fromWireName(String? value) => GestureAck.values.firstWhere(
    (ack) => ack.name == value,
    orElse: () => GestureAck.failed,
  );
}

abstract interface class ExternalTouchpadApi {
  Future<List<DisplayInfo>> getDisplays();
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId);
  Future<SessionState> getSessionState();
  Future<SessionState> startSession({int? displayId});
  Future<void> stopSession();
  Future<void> dismissSoftKeyboard();
  Future<void> restoreSoftKeyboard();

  Future<void> moveCursor(double dx, double dy);
  Future<GestureAck> commitPointerAction(
    PointerActionType type, {
    required bool showFeedback,
  });
  Future<GestureAck> beginContinuousGesture(int id, RemoteGestureKind kind);
  Future<GestureAck> updateContinuousGesture(int id, double dx, double dy);
  Future<GestureAck> endContinuousGesture(int id, {required bool cancelled});
  Future<void> updateInputDiagnostics({required String phase, int? sessionId});

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
  Future<void> setScreenBrightness(double? brightness);
  Future<List<HomeAppInfo>> getHomeApps();
  Future<List<HomeAppInfo>> getInstalledApps();
  Future<Uint8List?> getAppIcon(String packageName, String activityName);
  Future<bool> launchApp(String packageName, String activityName);

  Stream<ExternalTouchpadEvent> get events;
}
