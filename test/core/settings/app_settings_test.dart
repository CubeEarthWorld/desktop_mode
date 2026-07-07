import 'package:desktop_mode/core/settings/app_settings.dart';
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
      expect(restored.oledProtection, original.oledProtection);
      expect(restored.externalHomePackage, original.externalHomePackage);
      expect(restored.externalHomeActivity, original.externalHomeActivity);
      expect(restored.preferredDisplayModeId, original.preferredDisplayModeId);
    });

    test('fromJson falls back to defaults for missing fields', () {
      final restored = AppSettings.fromJson(const {});

      expect(restored.autoStart, true);
      expect(restored.pointerSpeed, 1.8);
      expect(restored.longPressDurationMs, 450);
      expect(restored.preferredDisplayId, isNull);
    });

    test('copyWith clearPreferredDisplayId clears the value', () {
      const withDisplay = AppSettings(preferredDisplayId: 7);
      final cleared = withDisplay.copyWith(clearPreferredDisplayId: true);

      expect(cleared.preferredDisplayId, isNull);
    });

    test('copyWith without clear flag preserves existing preferredDisplayId', () {
      const withDisplay = AppSettings(preferredDisplayId: 7);
      final updated = withDisplay.copyWith(pointerSpeed: 2.5);

      expect(updated.preferredDisplayId, 7);
      expect(updated.pointerSpeed, 2.5);
    });

    test('copyWith clearPreferredDisplayModeId clears the value', () {
      const withMode = AppSettings(preferredDisplayModeId: 3);
      final cleared = withMode.copyWith(clearPreferredDisplayModeId: true);

      expect(cleared.preferredDisplayModeId, isNull);
    });
  });
}
