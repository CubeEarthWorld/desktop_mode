import 'package:desktop_mode/features/touchpad/touchpad_gesture_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TouchpadGestureRecognizer', () {
    late TouchpadGestureRecognizer recognizer;

    setUp(() {
      recognizer = TouchpadGestureRecognizer();
    });

    test('single tap within duration and slop emits LeftClickResult', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      final result = recognizer.onPointerUp(1, const Duration(milliseconds: 100));

      expect(result, [isA<LeftClickResult>()]);
    });

    test('single tap held too long emits nothing', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      final result = recognizer.onPointerUp(1, const Duration(milliseconds: 300));

      expect(result, isEmpty);
    });

    test('single finger move beyond slop emits CursorMoveResult and suppresses tap', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(20, 0),
        const Duration(milliseconds: 20),
      );
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 40));

      expect(moveResult, [isA<CursorMoveResult>()]);
      expect(upResult, isEmpty);
    });

    test('move within slop does not emit CursorMoveResult', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(4, 0),
        const Duration(milliseconds: 20),
      );

      expect(moveResult, isEmpty);
    });

    test('two-finger tap within window emits nothing (right-click removed)', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      final firstUp = recognizer.onPointerUp(1, const Duration(milliseconds: 150));
      final secondUp = recognizer.onPointerUp(2, const Duration(milliseconds: 150));

      // 2本指タップは何も送らない(右クリックは廃止)。
      expect(firstUp, isEmpty);
      expect(secondUp, isEmpty);
    });

    test('second finger arriving after twoFingerWindow goes dead', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 200));
      recognizer.onPointerUp(1, const Duration(milliseconds: 250));
      final finalUp = recognizer.onPointerUp(2, const Duration(milliseconds: 250));

      expect(finalUp, isEmpty);
    });

    test('third finger forces dead state', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(10, 10), const Duration(milliseconds: 10));
      recognizer.onPointerDown(3, const Offset(20, 20), const Duration(milliseconds: 20));

      recognizer.onPointerUp(1, const Duration(milliseconds: 30));
      recognizer.onPointerUp(2, const Duration(milliseconds: 30));
      final finalUp = recognizer.onPointerUp(3, const Duration(milliseconds: 30));

      expect(finalUp, isEmpty);
    });

    test('recognizer returns to idle after all pointers lift', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onPointerUp(1, const Duration(milliseconds: 50));

      // 前回のタップ後、時間を空けての独立したタップは通常の左クリックとして扱われる。
      recognizer.onPointerDown(2, const Offset(0, 0), const Duration(milliseconds: 900));
      final result = recognizer.onPointerUp(2, const Duration(milliseconds: 950));

      expect(result, [isA<LeftClickResult>()]);
    });

    test('pointer cancel resets to idle without emitting click', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onPointerCancel(1);

      recognizer.onPointerDown(2, const Offset(0, 0), const Duration(milliseconds: 200));
      final result = recognizer.onPointerUp(2, const Duration(milliseconds: 250));

      expect(result, [isA<LeftClickResult>()]);
    });

    test('pointer cancel during drag emits DragEndResult so native state is released', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onLongPressTimeout(1);
      recognizer.onPointerMove(1, const Offset(30, 0), const Duration(milliseconds: 600));

      final cancelResult = recognizer.onPointerCancel(1);

      expect(cancelResult, [isA<DragEndResult>()]);

      // キャンセル後は正常に idle へ戻り、次のタップが通常通り効く。
      recognizer.onPointerDown(2, const Offset(0, 0), const Duration(milliseconds: 700));
      final result = recognizer.onPointerUp(2, const Duration(milliseconds: 750));
      expect(result, [isA<LeftClickResult>()]);
    });

    test('pointer cancel during two-finger swipe emits TwoFingerSwipeEndResult', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));

      final cancelResult = recognizer.onPointerCancel(1);
      expect(cancelResult, [isA<TwoFingerSwipeEndResult>()]);

      // 残った指がキャンセルされても、既に dead 状態なので何も送らない。
      final secondCancel = recognizer.onPointerCancel(2);
      expect(secondCancel, isEmpty);

      // 次のタップは通常通り効く。
      recognizer.onPointerDown(3, const Offset(0, 0), const Duration(milliseconds: 200));
      final result = recognizer.onPointerUp(3, const Duration(milliseconds: 250));
      expect(result, [isA<LeftClickResult>()]);
    });

    test('touch then move is always cursor move, never a tap, however fast', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(20, 0),
        const Duration(milliseconds: 5),
      );
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 10));

      expect(moveResult, [isA<CursorMoveResult>()]);
      expect(upResult, isEmpty);
    });

    test('re-touch after tap is independent and emits a click', () {
      // タップ直後の再タッチによるドラッグは削除済み。
      // 再タッチは独立した操作として扱われ、離すと通常のクリックが送られる。
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final firstUp = recognizer.onPointerUp(1, const Duration(milliseconds: 50));

      recognizer.onPointerDown(2, const Offset(2, 2), const Duration(milliseconds: 150));
      final upResult = recognizer.onPointerUp(2, const Duration(milliseconds: 200));

      expect(firstUp, [isA<LeftClickResult>()]);
      expect(upResult, [isA<LeftClickResult>()]);
    });

    test('re-touch after tap and move is cursor move, not drag', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onPointerUp(1, const Duration(milliseconds: 50));

      recognizer.onPointerDown(2, const Offset(2, 2), const Duration(milliseconds: 150));
      final moveResult = recognizer.onPointerMove(
        2,
        const Offset(30, 2),
        const Duration(milliseconds: 180),
      );

      expect(moveResult, [isA<CursorMoveResult>()]);
    });

    test('long press timeout without moving then release emits LongPressResult', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final timeoutResult = recognizer.onLongPressTimeout(1);
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 600));

      expect(timeoutResult, isEmpty);
      expect(upResult, [isA<LongPressResult>()]);
    });

    test('long press timeout then move starts a drag directly (no re-touch needed)', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onLongPressTimeout(1);
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(30, 0),
        const Duration(milliseconds: 600),
      );

      expect(moveResult, [isA<DragStartResult>(), isA<DragMoveResult>()]);
    });

    test('subsequent moves after long-press drag start emit DragMoveResult', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onLongPressTimeout(1);
      recognizer.onPointerMove(1, const Offset(30, 0), const Duration(milliseconds: 600));
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(50, 0),
        const Duration(milliseconds: 620),
      );

      expect(moveResult, [isA<DragMoveResult>()]);
    });

    test('long-press drag ends with DragEndResult on pointer up', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onLongPressTimeout(1);
      recognizer.onPointerMove(1, const Offset(30, 0), const Duration(milliseconds: 600));
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 700));

      expect(upResult, [isA<DragEndResult>()]);
    });

    test('long press timeout then tiny move starts a drag without slop', () {
      // 長押し後はわずかな動きでもドラッグ開始する。
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onLongPressTimeout(1);
      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(2, 0),
        const Duration(milliseconds: 600),
      );

      expect(moveResult, [isA<DragStartResult>(), isA<DragMoveResult>()]);
    });

    test('long press timeout has no effect once the finger already moved', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      recognizer.onPointerMove(1, const Offset(30, 0), const Duration(milliseconds: 20));
      final timeoutResult = recognizer.onLongPressTimeout(1);
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 600));

      expect(timeoutResult, isEmpty);
      expect(upResult, isEmpty);
    });

    test('long press timeout for an unrelated pointer id is ignored', () {
      recognizer.onPointerDown(1, const Offset(0, 0), const Duration(milliseconds: 0));
      final timeoutResult = recognizer.onLongPressTimeout(99);
      final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 100));

      expect(timeoutResult, isEmpty);
      // 武装されていないので通常の短時間タップとして扱われる。
      expect(upResult, [isA<LeftClickResult>()]);
    });

    test('two fingers moving together emit TwoFingerSwipeStart then half-delta moves', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

      final moveA = recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));
      expect(moveA, [isA<TwoFingerSwipeStartResult>(), isA<TwoFingerSwipeMoveResult>()]);
      final firstMove = moveA[1] as TwoFingerSwipeMoveResult;
      // 重心(2点平均)の移動量として、実際の移動量の半分を返す。
      expect(firstMove.dy, 15);

      final moveB = recognizer.onPointerMove(2, const Offset(50, 80), const Duration(milliseconds: 90));
      expect(moveB, [isA<TwoFingerSwipeMoveResult>()]);
      final secondMove = moveB.single as TwoFingerSwipeMoveResult;
      expect(secondMove.dy, 15);
      // 2指分を合算すると実際に動いた量(30+30)と一致する。
      expect(firstMove.dy + secondMove.dy, 30);
    });

    test('lifting one finger during two-finger swipe ends the gesture and ignores the rest', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));

      final endResult = recognizer.onPointerUp(1, const Duration(milliseconds: 100));
      expect(endResult, [isA<TwoFingerSwipeEndResult>()]);

      // 残った指の動きは無視される(誤ってカーソル移動やタップにならない)。
      final ignoredMove = recognizer.onPointerMove(
        2,
        const Offset(90, 50),
        const Duration(milliseconds: 110),
      );
      expect(ignoredMove, isEmpty);
      final ignoredUp = recognizer.onPointerUp(2, const Duration(milliseconds: 120));
      expect(ignoredUp, isEmpty);
    });

    test('two-finger tap without movement emits nothing but ends cleanly', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      final firstUp = recognizer.onPointerUp(1, const Duration(milliseconds: 150));
      final secondUp = recognizer.onPointerUp(2, const Duration(milliseconds: 150));

      expect(firstUp, isEmpty);
      expect(secondUp, isEmpty);
    });
  });
}
