import 'session_state.dart';

/// §4.1 のエラーコード。native からの `PlatformException.code` / `NativeError.code` と一致する。
abstract final class DesktopModeErrorCode {
  static const accessibilityDisabled = 'accessibility_disabled';
  static const displayNotFound = 'display_not_found';
  static const overlayFailed = 'overlay_failed';
  static const gestureFailed = 'gesture_failed';
  static const gestureBusy = 'gesture_busy';
  static const sessionNotActive = 'session_not_active';
  static const activityLaunchDenied = 'activity_launch_denied';
}

/// native → Flutter イベント(EventChannel `desktop_mode/display_events`)。
sealed class DesktopModeEvent {
  const DesktopModeEvent();

  factory DesktopModeEvent.fromMap(Map<Object?, Object?> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'displayAdded' => DisplayAddedEvent(map['displayId']! as int),
      'displayRemoved' => DisplayRemovedEvent(map['displayId']! as int),
      'displayChanged' => DisplayChangedEvent(map['displayId']! as int),
      'sessionStarted' => SessionStartedEvent(SessionState.fromMap(map)),
      'sessionStopped' => SessionStoppedEvent(map['reason'] as String? ?? 'unknown'),
      'accessibilityStateChanged' => AccessibilityStateChangedEvent(
        map['enabled'] as bool? ?? false,
      ),
      'error' => NativeErrorEvent(
        map['code'] as String? ?? 'unknown_error',
        map['message'] as String? ?? '',
      ),
      _ => NativeErrorEvent('unknown_event', 'Unknown event type: $type'),
    };
  }
}

class DisplayAddedEvent extends DesktopModeEvent {
  const DisplayAddedEvent(this.displayId);
  final int displayId;
}

class DisplayRemovedEvent extends DesktopModeEvent {
  const DisplayRemovedEvent(this.displayId);
  final int displayId;
}

class DisplayChangedEvent extends DesktopModeEvent {
  const DisplayChangedEvent(this.displayId);
  final int displayId;
}

class SessionStartedEvent extends DesktopModeEvent {
  const SessionStartedEvent(this.sessionState);
  final SessionState sessionState;
}

class SessionStoppedEvent extends DesktopModeEvent {
  const SessionStoppedEvent(this.reason);
  final String reason;
}

class AccessibilityStateChangedEvent extends DesktopModeEvent {
  const AccessibilityStateChangedEvent(this.enabled);
  final bool enabled;
}

class NativeErrorEvent extends DesktopModeEvent {
  const NativeErrorEvent(this.code, this.message);
  final String code;
  final String message;
}
