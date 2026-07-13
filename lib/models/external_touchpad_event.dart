import 'session_state.dart';

/// §4.1 のエラーコード。native からの `PlatformException.code` / `NativeError.code` と一致する。
abstract final class ExternalTouchpadErrorCode {
  static const accessibilityDisabled = 'accessibility_disabled';
  static const displayNotFound = 'display_not_found';
  static const overlayFailed = 'overlay_failed';
  static const gestureFailed = 'gesture_failed';
  static const gestureBusy = 'gesture_busy';
  static const sessionNotActive = 'session_not_active';
  static const activityLaunchDenied = 'activity_launch_denied';
}

/// native → Flutter イベント(EventChannel `external_touchpad/display_events`)。
sealed class ExternalTouchpadEvent {
  const ExternalTouchpadEvent();

  factory ExternalTouchpadEvent.fromMap(Map<Object?, Object?> map) {
    final type = map['type'] as String?;
    return switch (type) {
      'displayAdded' => DisplayAddedEvent(map['displayId']! as int),
      'displayRemoved' => DisplayRemovedEvent(map['displayId']! as int),
      'displayChanged' => DisplayChangedEvent(map['displayId']! as int),
      'sessionStarted' => SessionStartedEvent(SessionState.fromMap(map)),
      'sessionStopped' => SessionStoppedEvent(
        map['reason'] as String? ?? 'unknown',
      ),
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

class DisplayAddedEvent extends ExternalTouchpadEvent {
  const DisplayAddedEvent(this.displayId);
  final int displayId;
}

class DisplayRemovedEvent extends ExternalTouchpadEvent {
  const DisplayRemovedEvent(this.displayId);
  final int displayId;
}

class DisplayChangedEvent extends ExternalTouchpadEvent {
  const DisplayChangedEvent(this.displayId);
  final int displayId;
}

class SessionStartedEvent extends ExternalTouchpadEvent {
  const SessionStartedEvent(this.sessionState);
  final SessionState sessionState;
}

class SessionStoppedEvent extends ExternalTouchpadEvent {
  const SessionStoppedEvent(this.reason);
  final String reason;
}

class AccessibilityStateChangedEvent extends ExternalTouchpadEvent {
  const AccessibilityStateChangedEvent(this.enabled);
  final bool enabled;
}

class NativeErrorEvent extends ExternalTouchpadEvent {
  const NativeErrorEvent(this.code, this.message);
  final String code;
  final String message;
}
