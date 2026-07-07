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

/// 実 MethodChannel を叩かないフェイク実装。呼び出し順を記録する。
class _FakeDesktopModeApi implements DesktopModeApi {
  final List<String> calls = [];

  @override
  Future<List<DisplayInfo>> getDisplays() async => const [];

  @override
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId) async => const [];

  @override
  Future<SessionState> getSessionState() async => SessionState.idleState;

  @override
  Future<SessionState> startSession({int? displayId}) async => SessionState.idleState;

  @override
  Future<void> stopSession() async {
    calls.add('stopSession');
  }

  @override
  Future<void> moveCursor(double dx, double dy) async {
    calls.add('moveCursor($dx,$dy)');
  }

  @override
  Future<void> leftClick() async {
    calls.add('leftClick');
  }

  @override
  Future<void> longPress() async {
    calls.add('longPress');
  }

  @override
  Future<void> showTouchEffectAtCursor() async {
    calls.add('showTouchEffectAtCursor');
  }

  @override
  Future<void> pointerDown() async {
    calls.add('pointerDown');
  }

  @override
  Future<void> pointerMove(double dx, double dy) async {
    calls.add('pointerMove($dx,$dy)');
  }

  @override
  Future<void> pointerUp() async {
    calls.add('pointerUp');
  }

  @override
  Future<void> twoFingerScrollStart() async {
    calls.add('twoFingerScrollStart');
  }

  @override
  Future<void> twoFingerScrollBy(double dx, double dy) async {
    calls.add('twoFingerScrollBy($dx,$dy)');
  }

  @override
  Future<void> twoFingerScrollEnd() async {
    calls.add('twoFingerScrollEnd');
  }

  @override
  Future<void> twoFingerSwipe(double dx, double dy) async {
    calls.add('twoFingerSwipe($dx,$dy)');
  }

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

    testWidgets('movement during unlock hold cancels unlock', (tester) async {
      final container = _createContainer(const AppSettings(touchLockEnabled: true));

      await container.read(settingsProvider.future);
      container.listen(touchpadControllerProvider, (_, _) {});
      await tester.pump();

      final controller = container.read(touchpadControllerProvider.notifier);
      await tester.pump(const Duration(seconds: 30));
      expect(container.read(touchpadControllerProvider).locked, true);

      // ロック解除ホールドを開始する。
      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(touchpadControllerProvider).unlockHoldProgress, greaterThan(0));

      // 解除中に指を動かすと、解除は無効になりリセットされる。
      controller.handlePointerMove(1, const Offset(120, 120), Duration.zero);
      await tester.pump();
      expect(container.read(touchpadControllerProvider).unlockHoldProgress, 0);
      expect(container.read(touchpadControllerProvider).locked, true);

      // ホールドがキャンセルされた後は、規定時間待っても解除されない。
      await tester.pump(const Duration(milliseconds: 2000));
      expect(container.read(touchpadControllerProvider).locked, true);

      container.dispose();
    });

    testWidgets('lockNow immediately locks', (tester) async {
      final container = _createContainer(const AppSettings(touchLockEnabled: true));

      await container.read(settingsProvider.future);
      container.listen(touchpadControllerProvider, (_, _) {});
      await tester.pump();

      final controller = container.read(touchpadControllerProvider.notifier);
      expect(container.read(touchpadControllerProvider).locked, false);

      controller.lockNow();
      await tester.pump();

      expect(container.read(touchpadControllerProvider).locked, true);

      container.dispose();
    });
    group('gesture dispatch', () {
      testWidgets('drag start is delayed until first move', (tester) async {
        final container = _createContainer(
          const AppSettings(longPressDurationMs: 300, showTouchGlow: false),
        );

        await container.read(settingsProvider.future);
        container.listen(touchpadControllerProvider, (_, _) {});
        await tester.pump();

        final controller = container.read(touchpadControllerProvider.notifier);

        controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
        await tester.pump(const Duration(milliseconds: 300));
        // 長押し武装後もまだ pointerDown は送られていない。
        final api = container.read(desktopModeApiProvider) as _FakeDesktopModeApi;
        expect(api.calls.where((c) => c == 'pointerDown'), isEmpty);

        // 最初の移動と同時に pointerDown が送出される。
        controller.handlePointerMove(1, const Offset(120, 100), const Duration(milliseconds: 310));
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(api.calls, contains('pointerDown'));
        final downIndex = api.calls.indexOf('pointerDown');
        final moveIndex = api.calls.indexWhere((c) => c.startsWith('pointerMove'));
        expect(moveIndex, greaterThan(downIndex));

        controller.handlePointerUp(1, const Duration(milliseconds: 400));
        await tester.pump();
        expect(api.calls.last, 'pointerUp');

        container.dispose();
      });

      testWidgets('drag without movement only emits longPress, not pointerDown', (tester) async {
        final container = _createContainer(
          const AppSettings(longPressDurationMs: 300, showTouchGlow: false),
        );

        await container.read(settingsProvider.future);
        container.listen(touchpadControllerProvider, (_, _) {});
        await tester.pump();

        final controller = container.read(touchpadControllerProvider.notifier);
        final api = container.read(desktopModeApiProvider) as _FakeDesktopModeApi;

        controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
        await tester.pump(const Duration(milliseconds: 300));
        controller.handlePointerUp(1, const Duration(milliseconds: 400));
        await tester.pump();

        expect(api.calls, contains('longPress'));
        expect(api.calls.where((c) => c == 'pointerDown'), isEmpty);

        container.dispose();
      });

      testWidgets('two-finger scroll start is delayed until first move', (tester) async {
        final container = _createContainer(const AppSettings(showTouchGlow: false));

        await container.read(settingsProvider.future);
        container.listen(touchpadControllerProvider, (_, _) {});
        await tester.pump();

        final controller = container.read(touchpadControllerProvider.notifier);
        final api = container.read(desktopModeApiProvider) as _FakeDesktopModeApi;

        controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
        controller.handlePointerDown(2, const Offset(140, 100), const Duration(milliseconds: 50));
        await tester.pump();
        // 2本指を置いただけでは twoFingerScrollStart は送られていない。
        expect(api.calls.where((c) => c == 'twoFingerScrollStart'), isEmpty);

        controller.handlePointerMove(1, const Offset(100, 130), const Duration(milliseconds: 200));
        tester.binding.scheduleFrame();
        await tester.pump();
        expect(api.calls, contains('twoFingerScrollStart'));
        final startIndex = api.calls.indexOf('twoFingerScrollStart');
        final moveIndex = api.calls.indexWhere((c) => c.startsWith('twoFingerScrollBy'));
        expect(moveIndex, greaterThan(startIndex));

        controller.handlePointerUp(1, const Duration(milliseconds: 250));
        await tester.pump();
        expect(api.calls.last, 'twoFingerScrollEnd');

        container.dispose();
      });

      testWidgets('two-finger lift without movement emits no scroll start', (tester) async {
        final container = _createContainer(const AppSettings(showTouchGlow: false));

        await container.read(settingsProvider.future);
        container.listen(touchpadControllerProvider, (_, _) {});
        await tester.pump();

        final controller = container.read(touchpadControllerProvider.notifier);
        final api = container.read(desktopModeApiProvider) as _FakeDesktopModeApi;

        controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
        controller.handlePointerDown(2, const Offset(140, 100), const Duration(milliseconds: 50));
        controller.handlePointerUp(1, const Duration(milliseconds: 150));
        controller.handlePointerUp(2, const Duration(milliseconds: 150));
        await tester.pump();

        expect(api.calls.where((c) => c == 'twoFingerScrollStart'), isEmpty);
        expect(api.calls.where((c) => c == 'twoFingerScrollEnd'), isEmpty);
        expect(api.calls.where((c) => c.startsWith('twoFingerSwipe')), isEmpty);

        container.dispose();
      });

      testWidgets('quick two-finger slide emits swipe, not scroll', (tester) async {
        final container = _createContainer(const AppSettings(showTouchGlow: false));

        await container.read(settingsProvider.future);
        container.listen(touchpadControllerProvider, (_, _) {});
        await tester.pump();

        final controller = container.read(touchpadControllerProvider.notifier);
        final api = container.read(desktopModeApiProvider) as _FakeDesktopModeApi;

        controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
        controller.handlePointerDown(2, const Offset(140, 100), const Duration(milliseconds: 50));

        // 素早く右へ 50px 移動: 20ms で重心移動 25px = 1.25 px/ms >= 閾値
        controller.handlePointerMove(1, const Offset(150, 100), const Duration(milliseconds: 70));
        controller.handlePointerMove(2, const Offset(190, 100), const Duration(milliseconds: 70));

        controller.handlePointerUp(1, const Duration(milliseconds: 80));
        controller.handlePointerUp(2, const Duration(milliseconds: 80));
        await tester.pump();

        expect(api.calls.where((c) => c == 'twoFingerScrollStart'), isEmpty);
        expect(api.calls.where((c) => c.startsWith('twoFingerSwipe')), isNotEmpty);
        expect(api.calls.last, startsWith('twoFingerSwipe'));

        container.dispose();
      });
    });
  });
}
