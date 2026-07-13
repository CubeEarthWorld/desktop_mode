import 'package:external_touchpad/features/touchpad/touchpad_gesture_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TouchpadGestureRecognizer', () {
    late TouchpadGestureRecognizer recognizer;

    setUp(() => recognizer = TouchpadGestureRecognizer());

    test('commits a tap only on pointer up', () {
      expect(recognizer.onPointerDown(1, Offset.zero, Duration.zero), isEmpty);
      final id = recognizer.sessionId;
      expect(
        recognizer.onPointerUp(
          1,
          Offset.zero,
          const Duration(milliseconds: 250),
        ),
        [
          isA<LeftClickResult>().having(
            (result) => result.sessionId,
            'sessionId',
            id,
          ),
        ],
      );
      expect(recognizer.phase, TouchpadPhase.idle);
    });

    test('a slow release is not a tap', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      expect(
        recognizer.onPointerUp(
          1,
          Offset.zero,
          const Duration(milliseconds: 251),
        ),
        isEmpty,
      );
    });

    test(
      'first cursor move includes the cumulative displacement through slop',
      () {
        recognizer.onPointerDown(1, Offset.zero, Duration.zero);
        expect(
          recognizer.onPointerMove(
            1,
            const Offset(5, 0),
            const Duration(milliseconds: 10),
          ),
          isEmpty,
        );
        final results = recognizer.onPointerMove(
          1,
          const Offset(13, 0),
          const Duration(milliseconds: 20),
        );
        expect(results, hasLength(1));
        final move = results.single as CursorMoveResult;
        expect(move.dx, 13);
        expect(move.dy, 0);
        expect(
          recognizer.onPointerUp(
            1,
            const Offset(13, 0),
            const Duration(milliseconds: 30),
          ),
          isEmpty,
        );
      },
    );

    test('stale long-press timers cannot arm a newer session', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      final oldId = recognizer.sessionId!;
      recognizer.onPointerUp(1, Offset.zero, const Duration(milliseconds: 50));
      recognizer.onPointerDown(
        2,
        Offset.zero,
        const Duration(milliseconds: 100),
      );

      recognizer.onLongPressTimeout(2, oldId);

      expect(recognizer.phase, TouchpadPhase.oneFingerPending);
    });

    test(
      'long press arms drag and release without movement commits long press',
      () {
        recognizer.onPointerDown(1, Offset.zero, Duration.zero);
        final id = recognizer.sessionId!;
        recognizer.onLongPressTimeout(1, id);

        expect(recognizer.phase, TouchpadPhase.dragArmed);
        expect(
          recognizer.onPointerUp(1, Offset.zero, const Duration(seconds: 1)),
          [isA<LongPressResult>()],
        );
      },
    );

    test('movement after drag arm begins one continuous drag', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      final id = recognizer.sessionId!;
      recognizer.onLongPressTimeout(1, id);
      expect(
        recognizer.onPointerMove(
          1,
          const Offset(1, 0),
          const Duration(seconds: 1),
        ),
        isEmpty,
      );

      final start = recognizer.onPointerMove(
        1,
        const Offset(2, 0),
        const Duration(milliseconds: 1010),
      );
      expect(start, [
        isA<ContinuousGestureStartResult>().having(
          (result) => result.kind,
          'kind',
          ContinuousGestureKind.drag,
        ),
        isA<ContinuousGestureMoveResult>(),
      ]);
      final end = recognizer.onPointerUp(
        1,
        const Offset(2, 0),
        const Duration(milliseconds: 1020),
      );
      expect(
        end.single,
        isA<ContinuousGestureEndResult>()
            .having((result) => result.kind, 'kind', ContinuousGestureKind.drag)
            .having((result) => result.cancelled, 'cancelled', false),
      );
    });

    test('movement reported only on up becomes drag, not long press', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      final id = recognizer.sessionId!;
      recognizer.onLongPressTimeout(1, id);

      final results = recognizer.onPointerUp(
        1,
        const Offset(20, 0),
        const Duration(milliseconds: 1010),
      );

      expect(results, [
        isA<ContinuousGestureStartResult>(),
        isA<ContinuousGestureMoveResult>(),
        isA<ContinuousGestureEndResult>().having(
          (result) => result.cancelled,
          'cancelled',
          false,
        ),
      ]);
      expect(results.whereType<LongPressResult>(), isEmpty);
    });

    test('a late second finger still suppresses click', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      recognizer.onPointerDown(
        2,
        const Offset(40, 0),
        const Duration(milliseconds: 900),
      );

      expect(recognizer.phase, TouchpadPhase.twoFingerPending);
      expect(
        recognizer.onPointerUp(
          1,
          Offset.zero,
          const Duration(milliseconds: 910),
        ),
        isEmpty,
      );
      expect(recognizer.phase, TouchpadPhase.suppressed);
      expect(
        recognizer.onPointerUp(
          2,
          const Offset(40, 0),
          const Duration(milliseconds: 920),
        ),
        isEmpty,
      );
      expect(recognizer.phase, TouchpadPhase.idle);
    });

    test(
      'second finger can take over from cursor movement without a touch action',
      () {
        recognizer.onPointerDown(1, Offset.zero, Duration.zero);
        expect(
          recognizer.onPointerMove(
            1,
            const Offset(20, 0),
            const Duration(milliseconds: 20),
          ),
          [isA<CursorMoveResult>()],
        );

        expect(
          recognizer.onPointerDown(
            2,
            const Offset(40, 0),
            const Duration(milliseconds: 300),
          ),
          isEmpty,
        );
        expect(recognizer.phase, TouchpadPhase.twoFingerPending);
      },
    );

    test('two-finger centroid movement becomes a one-stream scroll', () {
      recognizer.onPointerDown(1, const Offset(10, 10), Duration.zero);
      recognizer.onPointerDown(
        2,
        const Offset(50, 10),
        const Duration(milliseconds: 300),
      );

      final start = recognizer.onPointerMove(
        1,
        const Offset(10, 40),
        const Duration(milliseconds: 320),
      );
      expect(start, [
        isA<ContinuousGestureStartResult>().having(
          (result) => result.kind,
          'kind',
          ContinuousGestureKind.scroll,
        ),
        isA<ContinuousGestureMoveResult>(),
      ]);
      expect((start[1] as ContinuousGestureMoveResult).dy, 15);

      final move = recognizer.onPointerMove(
        2,
        const Offset(50, 40),
        const Duration(milliseconds: 330),
      );
      expect((move.single as ContinuousGestureMoveResult).dy, 15);

      final end = recognizer.onPointerUp(
        1,
        const Offset(10, 40),
        const Duration(milliseconds: 340),
      );
      expect(
        end.single,
        isA<ContinuousGestureEndResult>()
            .having(
              (result) => result.kind,
              'kind',
              ContinuousGestureKind.scroll,
            )
            .having((result) => result.cancelled, 'cancelled', false),
      );
      expect(
        recognizer.onPointerMove(
          2,
          const Offset(70, 40),
          const Duration(milliseconds: 350),
        ),
        isEmpty,
      );
    });

    test('third pointer cancels an active scroll exactly once', () {
      recognizer.onPointerDown(1, const Offset(10, 10), Duration.zero);
      recognizer.onPointerDown(2, const Offset(50, 10), Duration.zero);
      recognizer.onPointerMove(
        1,
        const Offset(10, 40),
        const Duration(milliseconds: 20),
      );

      final cancel = recognizer.onPointerDown(
        3,
        const Offset(80, 10),
        const Duration(milliseconds: 30),
      );
      expect(
        cancel.single,
        isA<ContinuousGestureEndResult>().having(
          (result) => result.cancelled,
          'cancelled',
          true,
        ),
      );
      expect(recognizer.onPointerCancel(1), isEmpty);
      expect(recognizer.onPointerCancel(2), isEmpty);
      expect(recognizer.onPointerCancel(3), isEmpty);
      expect(recognizer.phase, TouchpadPhase.idle);
    });

    test('forceCancel releases active drag and next session works', () {
      recognizer.onPointerDown(1, Offset.zero, Duration.zero);
      final id = recognizer.sessionId!;
      recognizer.onLongPressTimeout(1, id);
      recognizer.onPointerMove(
        1,
        const Offset(20, 0),
        const Duration(seconds: 1),
      );

      expect(
        recognizer.forceCancel().single,
        isA<ContinuousGestureEndResult>().having(
          (result) => result.cancelled,
          'cancelled',
          true,
        ),
      );
      expect(recognizer.phase, TouchpadPhase.idle);

      recognizer.onPointerDown(2, Offset.zero, const Duration(seconds: 2));
      expect(
        recognizer.onPointerUp(
          2,
          Offset.zero,
          const Duration(milliseconds: 2050),
        ),
        [isA<LeftClickResult>()],
      );
    });
  });
}
