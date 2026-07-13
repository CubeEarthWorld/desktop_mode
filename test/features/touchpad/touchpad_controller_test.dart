import 'dart:async';
import 'dart:typed_data';

import 'package:external_touchpad/core/platform/external_touchpad_api.dart';
import 'package:external_touchpad/core/platform/external_touchpad_channel.dart';
import 'package:external_touchpad/core/settings/app_settings.dart';
import 'package:external_touchpad/core/settings/settings_provider.dart';
import 'package:external_touchpad/features/touchpad/touchpad_controller.dart';
import 'package:external_touchpad/models/external_touchpad_event.dart';
import 'package:external_touchpad/models/diagnostics_info.dart';
import 'package:external_touchpad/models/display_info.dart';
import 'package:external_touchpad/models/display_mode_info.dart';
import 'package:external_touchpad/models/home_app_info.dart';
import 'package:external_touchpad/models/session_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExternalTouchpadApi implements ExternalTouchpadApi {
  final List<String> inputCalls = [];
  int dismissSoftKeyboardCalls = 0;

  @override
  Future<List<DisplayInfo>> getDisplays() async => const [];
  @override
  Future<List<DisplayModeInfo>> getSupportedDisplayModes(int displayId) async =>
      const [];
  @override
  Future<SessionState> getSessionState() async => SessionState.idleState;
  @override
  Future<SessionState> startSession({int? displayId}) async =>
      SessionState.idleState;
  @override
  Future<void> stopSession() async {}
  @override
  Future<void> dismissSoftKeyboard() async {
    dismissSoftKeyboardCalls++;
  }

  @override
  Future<void> moveCursor(double dx, double dy) async =>
      inputCalls.add('cursor:$dx,$dy');
  @override
  Future<GestureAck> commitPointerAction(
    PointerActionType type, {
    required bool showFeedback,
  }) async {
    inputCalls.add('action:${type.name}:$showFeedback');
    return GestureAck.accepted;
  }

  @override
  Future<GestureAck> beginContinuousGesture(
    int id,
    RemoteGestureKind kind,
  ) async {
    inputCalls.add('begin:$id:${kind.name}');
    return GestureAck.accepted;
  }

  @override
  Future<GestureAck> updateContinuousGesture(
    int id,
    double dx,
    double dy,
  ) async {
    inputCalls.add('update:$id:$dx,$dy');
    return GestureAck.queued;
  }

  @override
  Future<GestureAck> endContinuousGesture(
    int id, {
    required bool cancelled,
  }) async {
    inputCalls.add('end:$id:$cancelled');
    return GestureAck.accepted;
  }

  @override
  Future<void> updateInputDiagnostics({
    required String phase,
    int? sessionId,
  }) async {}
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
  Future<Uint8List?> getAppIcon(
    String packageName,
    String activityName,
  ) async => null;
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
  Future<void> setScreenBrightness(double? brightness) async {}
  @override
  Stream<ExternalTouchpadEvent> get events => const Stream.empty();
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier(this._settings);
  final AppSettings _settings;

  @override
  Future<AppSettings> build() async => _settings;
}

({ProviderContainer container, _FakeExternalTouchpadApi api}) _createContainer(
  AppSettings settings,
) {
  final api = _FakeExternalTouchpadApi();
  final container = ProviderContainer(
    overrides: [
      externalTouchpadApiProvider.overrideWithValue(api),
      settingsProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
  );
  return (container: container, api: api);
}

Future<TouchpadController> _initialize(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await container.read(settingsProvider.future);
  container.listen(touchpadControllerProvider, (_, _) {});
  await tester.pump();
  return container.read(touchpadControllerProvider.notifier);
}

void main() {
  testWidgets('pointer down has no platform action or feedback', (
    tester,
  ) async {
    final setup = _createContainer(const AppSettings());
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, const Offset(10, 10), Duration.zero);
    await tester.pump();

    expect(setup.api.inputCalls, isEmpty);
    expect(setup.api.dismissSoftKeyboardCalls, 1);
    expect(
      setup.container.read(touchpadControllerProvider).fadingGlows,
      isEmpty,
    );
    setup.container.dispose();
  });

  testWidgets('tap commits one action and one release feedback', (
    tester,
  ) async {
    final setup = _createContainer(const AppSettings());
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, const Offset(10, 10), Duration.zero);
    controller.handlePointerUp(
      1,
      const Offset(10, 10),
      const Duration(milliseconds: 100),
    );
    await tester.pump();
    await controller.debugPendingCommands;

    expect(setup.api.inputCalls, ['action:click:true']);
    expect(
      setup.container.read(touchpadControllerProvider).fadingGlows,
      hasLength(1),
    );
    setup.container.dispose();
  });

  testWidgets('move and up in one frame are ordered begin update end', (
    tester,
  ) async {
    final setup = _createContainer(
      const AppSettings(longPressDurationMs: 1000),
    );
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, Offset.zero, Duration.zero);
    await tester.pump(const Duration(milliseconds: 1000));
    controller.handlePointerMove(
      1,
      const Offset(30, 0),
      const Duration(milliseconds: 1000),
    );
    controller.handlePointerUp(
      1,
      const Offset(30, 0),
      const Duration(milliseconds: 1001),
    );
    await tester.pump();
    await controller.debugPendingCommands;

    expect(setup.api.inputCalls, hasLength(3));
    expect(setup.api.inputCalls[0], startsWith('begin:'));
    expect(setup.api.inputCalls[1], startsWith('update:'));
    expect(setup.api.inputCalls[2], startsWith('end:'));
    expect(setup.api.inputCalls[2], endsWith(':false'));
    setup.container.dispose();
  });

  testWidgets('movement first reported on up starts drag, not long press', (
    tester,
  ) async {
    final setup = _createContainer(
      const AppSettings(longPressDurationMs: 1000),
    );
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, Offset.zero, Duration.zero);
    await tester.pump(const Duration(milliseconds: 1000));
    controller.handlePointerUp(
      1,
      const Offset(30, 0),
      const Duration(milliseconds: 1001),
    );
    await tester.pump();
    await controller.debugPendingCommands;

    expect(setup.api.inputCalls, hasLength(3));
    expect(setup.api.inputCalls[0], startsWith('begin:'));
    expect(setup.api.inputCalls[1], startsWith('update:'));
    expect(setup.api.inputCalls[2], startsWith('end:'));
    expect(setup.api.inputCalls, isNot(contains('action:longPress:true')));
    setup.container.dispose();
  });

  testWidgets('two-finger operation cannot emit a click', (tester) async {
    final setup = _createContainer(const AppSettings());
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, const Offset(10, 10), Duration.zero);
    controller.handlePointerDown(
      2,
      const Offset(50, 10),
      const Duration(milliseconds: 500),
    );
    controller.handlePointerUp(
      1,
      const Offset(10, 10),
      const Duration(milliseconds: 510),
    );
    controller.handlePointerUp(
      2,
      const Offset(50, 10),
      const Duration(milliseconds: 520),
    );
    await tester.pump();
    await controller.debugPendingCommands;

    expect(setup.api.inputCalls, isEmpty);
    setup.container.dispose();
  });

  testWidgets('two-finger move and up are ordered begin update end', (
    tester,
  ) async {
    final setup = _createContainer(const AppSettings());
    final controller = await _initialize(tester, setup.container);

    controller.handlePointerDown(1, const Offset(10, 10), Duration.zero);
    controller.handlePointerDown(
      2,
      const Offset(50, 10),
      const Duration(milliseconds: 400),
    );
    controller.handlePointerMove(
      1,
      const Offset(10, 40),
      const Duration(milliseconds: 410),
    );
    controller.handlePointerUp(
      1,
      const Offset(10, 40),
      const Duration(milliseconds: 411),
    );
    controller.handlePointerUp(
      2,
      const Offset(50, 10),
      const Duration(milliseconds: 412),
    );
    await tester.pump();
    await controller.debugPendingCommands;

    expect(setup.api.inputCalls, hasLength(3));
    expect(setup.api.inputCalls[0], contains(':scroll'));
    expect(setup.api.inputCalls[1], startsWith('update:'));
    expect(setup.api.inputCalls[2], endsWith(':false'));

    setup.api.inputCalls.clear();
    controller.handlePointerDown(3, Offset.zero, const Duration(seconds: 1));
    controller.handlePointerUp(
      3,
      Offset.zero,
      const Duration(milliseconds: 1100),
    );
    await tester.pump();
    await controller.debugPendingCommands;
    expect(setup.api.inputCalls, ['action:click:true']);
    setup.container.dispose();
  });

  group('lock', () {
    testWidgets('uses the configured 5-second idle timeout', (tester) async {
      final setup = _createContainer(
        const AppSettings(
          touchLockEnabled: true,
          touchLockIdleTimeoutSeconds: 5,
        ),
      );
      await _initialize(tester, setup.container);

      await tester.pump(const Duration(milliseconds: 4999));
      expect(setup.container.read(touchpadControllerProvider).locked, false);

      await tester.pump(const Duration(milliseconds: 1));
      expect(setup.container.read(touchpadControllerProvider).locked, true);
      setup.container.dispose();
    });

    testWidgets('auto-locks and unlocks with long press', (tester) async {
      final setup = _createContainer(const AppSettings(touchLockEnabled: true));
      final controller = await _initialize(tester, setup.container);

      await tester.pump(const Duration(seconds: 30));
      expect(setup.container.read(touchpadControllerProvider).locked, true);

      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 1050));
      expect(setup.container.read(touchpadControllerProvider).locked, false);
      setup.container.dispose();
    });

    testWidgets('short locked tap does not unlock', (tester) async {
      final setup = _createContainer(const AppSettings(touchLockEnabled: true));
      final controller = await _initialize(tester, setup.container);

      await tester.pump(const Duration(seconds: 30));
      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));
      controller.handlePointerUp(1, const Offset(100, 100), Duration.zero);
      await tester.pump();

      expect(setup.container.read(touchpadControllerProvider).locked, true);
      setup.container.dispose();
    });

    testWidgets('moving the finger during unlock hold fails the unlock', (
      tester,
    ) async {
      final setup = _createContainer(const AppSettings(touchLockEnabled: true));
      final controller = await _initialize(tester, setup.container);

      await tester.pump(const Duration(seconds: 30));
      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));
      // スロップ(12px)を超える移動 → 解除失敗(離したときと同じ扱い)。
      controller.handlePointerMove(
        1,
        const Offset(140, 100),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 1000));

      expect(setup.container.read(touchpadControllerProvider).locked, true);
      expect(
        setup.container.read(touchpadControllerProvider).unlockHoldProgress,
        0,
      );
      setup.container.dispose();
    });

    testWidgets('small jitter during unlock hold still unlocks', (
      tester,
    ) async {
      final setup = _createContainer(const AppSettings(touchLockEnabled: true));
      final controller = await _initialize(tester, setup.container);

      await tester.pump(const Duration(seconds: 30));
      controller.handlePointerDown(1, const Offset(100, 100), Duration.zero);
      controller.handlePointerMove(
        1,
        const Offset(105, 100),
        const Duration(milliseconds: 200),
      );
      await tester.pump(const Duration(milliseconds: 1050));

      expect(setup.container.read(touchpadControllerProvider).locked, false);
      setup.container.dispose();
    });

    testWidgets('lockNow locks immediately when touch lock is enabled', (
      tester,
    ) async {
      final setup = _createContainer(const AppSettings(touchLockEnabled: true));
      final controller = await _initialize(tester, setup.container);

      expect(setup.container.read(touchpadControllerProvider).locked, false);
      controller.lockNow();
      expect(setup.container.read(touchpadControllerProvider).locked, true);
      setup.container.dispose();
    });

    testWidgets('lockNow is a no-op when touch lock is disabled', (
      tester,
    ) async {
      final setup = _createContainer(const AppSettings());
      final controller = await _initialize(tester, setup.container);

      controller.lockNow();
      expect(setup.container.read(touchpadControllerProvider).locked, false);
      setup.container.dispose();
    });
  });
}
