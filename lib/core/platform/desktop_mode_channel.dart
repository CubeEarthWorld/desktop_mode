import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/desktop_mode_event.dart';
import '../../models/diagnostics_info.dart';
import '../../models/display_info.dart';
import '../../models/display_mode_info.dart';
import '../../models/home_app_info.dart';
import '../../models/session_state.dart';
import 'desktop_mode_api.dart';

final desktopModeApiProvider = Provider<DesktopModeApi>(
  (ref) => DesktopModeChannel(),
);

/// EventChannel は購読者の有無に関わらず1本のブロードキャストストリームを共有する。
final desktopModeEventsProvider = StreamProvider<DesktopModeEvent>(
  (ref) => ref.watch(desktopModeApiProvider).events,
);

/// `DesktopModeApi` の MethodChannel/EventChannel 実装。変換のみを行い、ロジックは持たない。
class DesktopModeChannel implements DesktopModeApi {
  DesktopModeChannel()
    : _method = const MethodChannel('desktop_mode/control'),
      _eventChannel = const EventChannel('desktop_mode/display_events');

  final MethodChannel _method;
  final EventChannel _eventChannel;

  @override
  Future<List<DisplayInfo>> getDisplays() async {
    final result = await _method.invokeMethod<List<Object?>>('getDisplays');
    return (result ?? const [])
        .map((e) => DisplayInfo.fromMap(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId) async {
    final result = await _method.invokeMethod<List<Object?>>(
      'getSupportedDisplayModes',
      {'displayId': displayId},
    );
    return (result ?? const [])
        .map((e) => DisplayModeInfo.fromMap(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<SessionState> getSessionState() async {
    final result = await _method.invokeMapMethod<Object?, Object?>(
      'getSessionState',
    );
    return SessionState.fromMap(result ?? const {});
  }

  @override
  Future<SessionState> startSession({int? displayId}) async {
    final result = await _method.invokeMapMethod<Object?, Object?>(
      'startSession',
      {'displayId': displayId},
    );
    return SessionState.fromMap(result ?? const {});
  }

  @override
  Future<void> stopSession() => _method.invokeMethod('stopSession');

  @override
  Future<void> moveCursor(double dx, double dy) =>
      _method.invokeMethod('moveCursor', {'dx': dx, 'dy': dy});

  @override
  Future<void> leftClick() => _method.invokeMethod('leftClick');

  @override
  Future<void> longPress() => _method.invokeMethod('longPress');

  @override
  Future<void> showTouchEffectAtCursor() =>
      _method.invokeMethod('showTouchEffectAtCursor');

  @override
  Future<void> pointerDown() => _method.invokeMethod('pointerDown');

  @override
  Future<void> pointerMove(double dx, double dy) =>
      _method.invokeMethod('pointerMove', {'dx': dx, 'dy': dy});

  @override
  Future<void> pointerUp() => _method.invokeMethod('pointerUp');

  @override
  Future<void> twoFingerMoveStart() => _method.invokeMethod('twoFingerMoveStart');

  @override
  Future<void> twoFingerMoveBy(double dx, double dy) =>
      _method.invokeMethod('twoFingerMoveBy', {'dx': dx, 'dy': dy});

  @override
  Future<void> twoFingerMoveEnd() => _method.invokeMethod('twoFingerMoveEnd');

  @override
  Future<bool> systemAction(String action) async =>
      (await _method.invokeMethod<bool>('systemAction', {'action': action})) ??
      false;

  @override
  Future<void> updateConfig({
    required double pointerSpeed,
    required int longPressDurationMs,
    required bool showCursor,
    required int cursorIdleTimeoutMs,
    String? externalHomePackage,
    String? externalHomeActivity,
    int? preferredDisplayModeId,
  }) => _method.invokeMethod('updateConfig', {
    'pointerSpeed': pointerSpeed,
    'longPressDurationMs': longPressDurationMs,
    'showCursor': showCursor,
    'cursorIdleTimeoutMs': cursorIdleTimeoutMs,
    'externalHomePackage': externalHomePackage,
    'externalHomeActivity': externalHomeActivity,
    'preferredDisplayModeId': preferredDisplayModeId,
  });

  @override
  Future<List<HomeAppInfo>> getHomeApps() async {
    final result = await _method.invokeMethod<List<Object?>>('getHomeApps');
    return (result ?? const [])
        .map((e) => HomeAppInfo.fromMap(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<List<HomeAppInfo>> getInstalledApps() async {
    final result = await _method.invokeMethod<List<Object?>>('getInstalledApps');
    return (result ?? const [])
        .map((e) => HomeAppInfo.fromMap(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<bool> launchApp(String packageName, String activityName) async =>
      (await _method.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
        'activityName': activityName,
      })) ??
      false;

  @override
  Future<DiagnosticsInfo> getDiagnostics() async {
    final result = await _method.invokeMapMethod<Object?, Object?>(
      'getDiagnostics',
    );
    return DiagnosticsInfo.fromMap(result ?? const {});
  }

  @override
  Future<bool> isAccessibilityEnabled() async =>
      (await _method.invokeMethod<bool>('isAccessibilityEnabled')) ?? false;

  @override
  Future<void> openAccessibilitySettings() =>
      _method.invokeMethod('openAccessibilitySettings');

  @override
  Future<bool> setResidentMonitoring(bool enabled) async =>
      (await _method.invokeMethod<bool>('setResidentMonitoring', {
        'enabled': enabled,
      })) ??
      false;

  @override
  Stream<DesktopModeEvent> get events => _eventChannel
      .receiveBroadcastStream()
      .map((event) => DesktopModeEvent.fromMap(event as Map<Object?, Object?>));
}
