import 'package:desktop_mode/models/desktop_mode_event.dart';
import 'package:desktop_mode/models/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DesktopModeEvent.fromMap', () {
    test('parses displayAdded', () {
      final event = DesktopModeEvent.fromMap({'type': 'displayAdded', 'displayId': 3});

      expect(event, isA<DisplayAddedEvent>());
      expect((event as DisplayAddedEvent).displayId, 3);
    });

    test('parses sessionStarted with nested session state', () {
      final event = DesktopModeEvent.fromMap({
        'type': 'sessionStarted',
        'status': 'active',
        'targetDisplayId': 5,
        'overlayActive': true,
      });

      expect(event, isA<SessionStartedEvent>());
      final session = (event as SessionStartedEvent).sessionState;
      expect(session.status, SessionStatus.active);
      expect(session.targetDisplayId, 5);
      expect(session.overlayActive, true);
    });

    test('parses sessionStopped with reason', () {
      final event = DesktopModeEvent.fromMap({
        'type': 'sessionStopped',
        'reason': 'displayRemoved',
      });

      expect(event, isA<SessionStoppedEvent>());
      expect((event as SessionStoppedEvent).reason, 'displayRemoved');
    });

    test('parses error event with code and message', () {
      final event = DesktopModeEvent.fromMap({
        'type': 'error',
        'code': 'gesture_busy',
        'message': '前のジェスチャが処理中です',
      });

      expect(event, isA<NativeErrorEvent>());
      final error = event as NativeErrorEvent;
      expect(error.code, DesktopModeErrorCode.gestureBusy);
      expect(error.message, '前のジェスチャが処理中です');
    });

    test('unknown type falls back to NativeErrorEvent', () {
      final event = DesktopModeEvent.fromMap({'type': 'somethingNew'});

      expect(event, isA<NativeErrorEvent>());
    });
  });
}
