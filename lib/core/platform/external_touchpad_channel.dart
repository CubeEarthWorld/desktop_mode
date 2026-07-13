import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/external_touchpad_event.dart';
import '../../models/diagnostics_info.dart';
import '../../models/display_info.dart';
import '../../models/display_mode_info.dart';
import '../../models/home_app_info.dart';
import '../../models/session_state.dart';
import 'external_touchpad_api.dart';

final externalTouchpadApiProvider = Provider<ExternalTouchpadApi>(
  (ref) => ExternalTouchpadChannel(),
);

final externalTouchpadEventsProvider = StreamProvider<ExternalTouchpadEvent>(
  (ref) => ref.watch(externalTouchpadApiProvider).events,
);

class ExternalTouchpadChannel implements ExternalTouchpadApi {
  ExternalTouchpadChannel()
    : _method = const MethodChannel('external_touchpad/control'),
      _eventChannel = const EventChannel('external_touchpad/display_events');

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
  Future<GestureAck> commitPointerAction(
    PointerActionType type, {
    required bool showFeedback,
  }) async => GestureAck.fromWireName(
    await _method.invokeMethod<String>('commitPointerAction', {
      'type': type.name,
      'showFeedback': showFeedback,
    }),
  );

  @override
  Future<GestureAck> beginContinuousGesture(
    int id,
    RemoteGestureKind kind,
  ) async => GestureAck.fromWireName(
    await _method.invokeMethod<String>('beginContinuousGesture', {
      'id': id,
      'kind': kind.name,
    }),
  );

  @override
  Future<GestureAck> updateContinuousGesture(
    int id,
    double dx,
    double dy,
  ) async => GestureAck.fromWireName(
    await _method.invokeMethod<String>('updateContinuousGesture', {
      'id': id,
      'dx': dx,
      'dy': dy,
    }),
  );

  @override
  Future<GestureAck> endContinuousGesture(
    int id, {
    required bool cancelled,
  }) async => GestureAck.fromWireName(
    await _method.invokeMethod<String>('endContinuousGesture', {
      'id': id,
      'cancelled': cancelled,
    }),
  );

  @override
  Future<void> updateInputDiagnostics({
    required String phase,
    int? sessionId,
  }) => _method.invokeMethod('updateInputDiagnostics', {
    'phase': phase,
    'sessionId': sessionId,
  });

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
    Map<String, String> appWindowModes = const {},
  }) => _method.invokeMethod('updateConfig', {
    'pointerSpeed': pointerSpeed,
    'longPressDurationMs': longPressDurationMs,
    'showCursor': showCursor,
    'cursorIdleTimeoutMs': cursorIdleTimeoutMs,
    'externalHomePackage': externalHomePackage,
    'externalHomeActivity': externalHomeActivity,
    'preferredDisplayModeId': preferredDisplayModeId,
    'appWindowModes': appWindowModes,
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
    final result = await _method.invokeMethod<List<Object?>>(
      'getInstalledApps',
    );
    return (result ?? const [])
        .map((e) => HomeAppInfo.fromMap(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName, String activityName) =>
      _method.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
        'activityName': activityName,
      });

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
  Future<void> setScreenBrightness(double? brightness) =>
      _method.invokeMethod('setScreenBrightness', {'brightness': brightness});

  @override
  Stream<ExternalTouchpadEvent> get events =>
      _eventChannel.receiveBroadcastStream().map(
        (event) =>
            ExternalTouchpadEvent.fromMap(event as Map<Object?, Object?>),
      );
}
