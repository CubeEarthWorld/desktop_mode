import 'package:external_touchpad/core/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('round-trips through JSON with all fields modified from defaults', () {
      const original = AppSettings(
        autoStart: false,
        residentMonitoring: true,
        showCursor: false,
        showTouchGlow: false,
        pointerSpeed: 3.2,
        longPressDurationMs: 700,
        cursorIdleTimeoutMs: 5000,
        preferredDisplayId: 42,
        touchLockEnabled: true,
        touchLockIdleTimeoutSeconds: 10,
        minimizeBrightnessWhileLocked: true,
        oledProtection: true,
        externalHomePackage: 'com.teslacoilsw.launcher',
        externalHomeActivity: 'com.teslacoilsw.launcher.NovaLauncher',
        preferredDisplayModeId: 3,
      );

      final restored = AppSettings.fromJson(original.toJson());

      expect(restored.autoStart, original.autoStart);
      expect(restored.residentMonitoring, original.residentMonitoring);
      expect(restored.showCursor, original.showCursor);
      expect(restored.showTouchGlow, original.showTouchGlow);
      expect(restored.pointerSpeed, original.pointerSpeed);
      expect(restored.longPressDurationMs, original.longPressDurationMs);
      expect(restored.cursorIdleTimeoutMs, original.cursorIdleTimeoutMs);
      expect(restored.preferredDisplayId, original.preferredDisplayId);
      expect(restored.touchLockEnabled, original.touchLockEnabled);
      expect(
        restored.touchLockIdleTimeoutSeconds,
        original.touchLockIdleTimeoutSeconds,
      );
      expect(
        restored.minimizeBrightnessWhileLocked,
        original.minimizeBrightnessWhileLocked,
      );
      expect(restored.oledProtection, original.oledProtection);
      expect(restored.externalHomePackage, original.externalHomePackage);
      expect(restored.externalHomeActivity, original.externalHomeActivity);
      expect(restored.preferredDisplayModeId, original.preferredDisplayModeId);
    });

    test('fromJson falls back to defaults for missing fields', () {
      final restored = AppSettings.fromJson(const {});

      expect(restored.autoStart, true);
      expect(restored.pointerSpeed, 1.8);
      expect(
        restored.longPressDurationMs,
        AppSettings.defaultLongPressDurationMs,
      );
      expect(restored.preferredDisplayId, isNull);
      expect(restored.touchLockIdleTimeoutSeconds, 30);
      expect(restored.minimizeBrightnessWhileLocked, false);
    });

    test('invalid touch-lock timeout falls back to 30 seconds', () {
      final restored = AppSettings.fromJson(const {
        'touchLockIdleTimeoutSeconds': 20,
      });

      expect(restored.touchLockIdleTimeoutSeconds, 30);
    });

    test('migrates only legacy default long-press values', () {
      // v1 の既定値 550ms → v2 で 1000ms → v3 で 500ms へ連鎖移行する。
      expect(
        AppSettings.fromJson(const {
          'longPressDurationMs': 550,
        }).longPressDurationMs,
        500,
      );
      // v2 の既定値 1000ms は v3 の既定値 500ms へ移行する。
      expect(
        AppSettings.fromJson(const {
          'schemaVersion': 2,
          'longPressDurationMs': 1000,
        }).longPressDurationMs,
        500,
      );
      // ユーザーが明示的に設定した値は保持される。
      expect(
        AppSettings.fromJson(const {
          'longPressDurationMs': 700,
        }).longPressDurationMs,
        700,
      );
      // v3 で保存された 1000ms は明示的な設定値なので保持される。
      expect(
        AppSettings.fromJson(const {
          'schemaVersion': 3,
          'longPressDurationMs': 1000,
        }).longPressDurationMs,
        1000,
      );
    });

    test('copyWith clearPreferredDisplayId clears the value', () {
      const withDisplay = AppSettings(preferredDisplayId: 7);
      final cleared = withDisplay.copyWith(clearPreferredDisplayId: true);

      expect(cleared.preferredDisplayId, isNull);
    });

    test(
      'copyWith without clear flag preserves existing preferredDisplayId',
      () {
        const withDisplay = AppSettings(preferredDisplayId: 7);
        final updated = withDisplay.copyWith(pointerSpeed: 2.5);

        expect(updated.preferredDisplayId, 7);
        expect(updated.pointerSpeed, 2.5);
      },
    );

    test('copyWith clearPreferredDisplayModeId clears the value', () {
      const withMode = AppSettings(preferredDisplayModeId: 3);
      final cleared = withMode.copyWith(clearPreferredDisplayModeId: true);

      expect(cleared.preferredDisplayModeId, isNull);
    });
  });
}
