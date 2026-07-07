import 'dart:async';

import 'package:desktop_mode/core/platform/desktop_mode_api.dart';
import 'package:desktop_mode/core/platform/desktop_mode_channel.dart';
import 'package:desktop_mode/core/settings/app_settings.dart';
import 'package:desktop_mode/core/settings/settings_provider.dart';
import 'package:desktop_mode/features/touchpad/touchpad_controller.dart';
import 'package:desktop_mode/models/desktop_mode_event.dart';
import 'package:desktop_mode/models/diagnostics_info.dart';
import 'package:desktop_mode/models/display_info.dart';
import 'package:desktop_mode/models/display_mode_info.dart';
import 'package:desktop_mode/models/home_app_info.dart';
import 'package:desktop_mode/models/session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実 MethodChannel を叩かないフェイク実装。
class _FakeDesktopModeApi implements DesktopModeApi {
  @override
  Future<List<DisplayInfo>> getDisplays() async => const [];

  @override
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId) async => const [];

  @override
  Future<SessionState> getSessionState() async => SessionState.idleState;

  @override
  Future<SessionState> startSession({int? displayId}) async => SessionState.idleState;

  @override
  Future<void> stopSession() async {}

  @override
  Future<void> moveCursor(double dx, double dy) async {}

  @override
  Future<void> leftClick() async {}

  @override
  Future<void> rightClick() async {}

  @override
  Future<void> showTouchEffectAtCursor() async {}

  @override
  Future<void> pointerDown() async {}

  @override
  Future<void> pointerMove(double dx, double dy) async {}

  @override
  Future<void> pointerUp() async {}

  @override
  Future<void> twoFingerMoveStart() async {}

  @override
  Future<void> twoFingerMoveBy(double aDx, double aDy, double bDx, double bDy) async {}

  @override
  Future<void> twoFingerMoveEnd() async {}

  @override
  Future<bool> systemAction(String action) async => true;

  @override
  Future<void> updateConfig({
    required double pointerSpeed,
    required int longPressDurationMs,
    required bool showCursor,
    required int cursorIdleTimeoutMs,
    String? externalHomePackage,
    String? externalHomeActivity,
    int? preferredDisplayModeId,
  }) async {}

  @override
  Future<List<HomeAppInfo>> getHomeApps() async => const [];

  @override
  Future<List<HomeAppInfo>> getInstalledApps() async => const [];

  @override
  Future<bool> launchApp(String packageName, String activityName) async => true;

  @override
  Future<DiagnosticsInfo> getDiagnostics() async => const DiagnosticsInfo(
    accessibilityEnabled: false,
    displays: [],
    targetDisplayId: null,
    displayBounds: null,
    hasSecondaryDisplayFeature: false,
    overlayActive: false,
    lastGestureResult: 'none',
    lastError: null,
  );

  @override
  Future<bool> isAccessibilityEnabled() async => false;

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<bool> setResidentMonitoring(bool enabled) async => enabled;

  @override
  Stream<DesktopModeEvent> get events => const Stream<DesktopModeEvent>.empty();
}

/// 固定値を返すフェイク設定リポジトリ。
class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._settings);
  final AppSettings _settings;

  @override
  Future<AppSettings> build() async => _settings;
}

ProviderContainer _createContainer(AppSettings settings) {
  return ProviderContainer(
    overrides: [
      desktopModeApiProvider.overrideWithValue(_FakeDesktopModeApi()),
      settingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
  );
}

void main() {
  group('TouchpadController lock', () {
    testWidgets('auto-locks after idle delay and unlocks with long press', (tester) async {
      final container = _createContainer(const AppSettings(touchLockEnabled: true));

      // 設定の読み込みが完了してからコントローラを生成する。
      await container.read(settingsProvider.future);
      container.listen(touchpadControllerProvider, (_, _) {});
      await tester.pump();

      final controller = container.read(touchpadControllerProvider.notifier);
      expect(container.read(touchpadControllerProvider).locked, false);

      // 30 秒無操作でロックされる。
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(touchpadControllerProvider).locked, true);

      // ロック中のタッチで解除ホールドが開始される。
      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(touchpadControllerProvider).unlockHoldProgress, greaterThan(0));

      // 2 秒長押しで解除される。
      await tester.pump(const Duration(milliseconds: 2000));
      expect(container.read(touchpadControllerProvider).locked, false);
      expect(container.read(touchpadControllerProvider).unlockHoldProgress, 0);

      container.dispose();
    });

    testWidgets('short tap while locked does not unlock', (tester) async {
      final container = _createContainer(const AppSettings(touchLockEnabled: true));

      await container.read(settingsProvider.future);
      container.listen(touchpadControllerProvider, (_, _) {});
      await tester.pump();

      final controller = container.read(touchpadControllerProvider.notifier);
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(touchpadControllerProvider).locked, true);

      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));
      controller.handlePointerUp(1, Duration.zero);
      await tester.pump();

      expect(container.read(touchpadControllerProvider).locked, true);

      container.dispose();
    });
  });
}
