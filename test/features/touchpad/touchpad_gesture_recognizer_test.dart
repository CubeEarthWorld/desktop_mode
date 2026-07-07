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

    test('single tap held too long emits nothing when long press threshold has not elapsed', () {
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
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 360));
      recognizer.onPointerUp(1, const Duration(milliseconds: 400));
      final finalUp = recognizer.onPointerUp(2, const Duration(milliseconds: 400));

      expect(finalUp, isEmpty);
    });

    test('second finger recognized even if first finger nudged slightly', () {
      // 1本目の指がわずかに動いても、累積距離が tapSlop 未満なら2本指として認識する。
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerMove(
        1,
        const Offset(11, 11),
        const Duration(milliseconds: 20),
      );
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 80));

      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(11, 20),
        const Duration(milliseconds: 100),
      );
      expect(moveResult, [isA<TwoFingerScrollStartResult>(), isA<TwoFingerScrollMoveResult>()]);
    });

    test('second finger ignored when first finger clearly moved', () {
      // 1本目が明らかに動いた後に2本目を追加しても、2本指にはならない。
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerMove(
        1,
        const Offset(30, 10),
        const Duration(milliseconds: 20),
      );
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 80));

      final moveResult = recognizer.onPointerMove(
        2,
        const Offset(60, 60),
        const Duration(milliseconds: 100),
      );
      expect(moveResult, isEmpty);
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

    test('pointer cancel during two-finger scroll emits TwoFingerScrollEndResult', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));

      final cancelResult = recognizer.onPointerCancel(1);
      expect(cancelResult, [isA<TwoFingerScrollEndResult>()]);

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

    test('two fingers moving slowly emit TwoFingerScrollStart then half-delta moves', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

      // ゆっくり移動: 80ms で 30px = 0.375 px/ms < スワイプ閾値
      final moveA = recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));
      expect(moveA, [isA<TwoFingerScrollStartResult>(), isA<TwoFingerScrollMoveResult>()]);
      final firstMove = moveA[1] as TwoFingerScrollMoveResult;
      // 重心の移動量を返す。1本目のみ動いたので重心は 15px 動く。
      expect(firstMove.dy, 15);

      final moveB = recognizer.onPointerMove(2, const Offset(50, 80), const Duration(milliseconds: 160));
      expect(moveB, [isA<TwoFingerScrollMoveResult>()]);
      final secondMove = moveB.single as TwoFingerScrollMoveResult;
      expect(secondMove.dy, 15);
      // 2指分を合算すると実際に動いた量(30+30)と一致する。
      expect(firstMove.dy + secondMove.dy, 30);

      final endResult = recognizer.onPointerUp(1, const Duration(milliseconds: 200));
      expect(endResult, [isA<TwoFingerScrollEndResult>()]);
    });

    test('lifting one finger during two-finger scroll ends the gesture and ignores the rest', () {
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));
      recognizer.onPointerMove(1, const Offset(10, 40), const Duration(milliseconds: 80));

      final endResult = recognizer.onPointerUp(1, const Duration(milliseconds: 100));
      expect(endResult, [isA<TwoFingerScrollEndResult>()]);

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

    test('two-finger tiny movement immediately starts scroll without slop', () {
      // tapSlop(12px) を大幅に下回るわずかな動きでも、2本指状態では即座に
      // スクロールとして認識する。
      recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
      recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

      final moveResult = recognizer.onPointerMove(
        1,
        const Offset(11, 11),
        const Duration(milliseconds: 80),
      );
      expect(moveResult, [isA<TwoFingerScrollStartResult>(), isA<TwoFingerScrollMoveResult>()]);
    });

    group('two-finger swipe', () {
      test('quick two-finger slide emits swipe result on release', () {
        recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
        recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

        // 素早く右方向へ 50px 移動: 20ms で重心移動 25px = 1.25 px/ms >= 閾値
        recognizer.onPointerMove(1, const Offset(60, 10), const Duration(milliseconds: 70));
        recognizer.onPointerMove(2, const Offset(100, 50), const Duration(milliseconds: 70));

        final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 80));
        recognizer.onPointerUp(2, const Duration(milliseconds: 80));

        expect(upResult, [isA<TwoFingerSwipeResult>()]);
        final swipe = upResult.single as TwoFingerSwipeResult;
        expect(swipe.dx, greaterThan(0));
      });

      test('slow two-finger slide emits scroll, not swipe', () {
        recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
        recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

        // ゆっくり右方向へ 50px 移動: 200ms で重心移動 25px = 0.125 px/ms < 閾値
        recognizer.onPointerMove(1, const Offset(60, 10), const Duration(milliseconds: 250));
        recognizer.onPointerMove(2, const Offset(100, 50), const Duration(milliseconds: 250));

        final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 300));
        expect(upResult, [isA<TwoFingerScrollEndResult>()]);
      });

      test('scroll transitions to swipe when movement becomes fast', () {
        recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
        recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

        // 最初はゆっくり（スクロール）
        final slowMove = recognizer.onPointerMove(
          1,
          const Offset(15, 10),
          const Duration(milliseconds: 150),
        );
        expect(slowMove, [isA<TwoFingerScrollStartResult>(), isA<TwoFingerScrollMoveResult>()]);

        // その後素早く移動（スワイプへ遷移）
        final fastMove = recognizer.onPointerMove(
          1,
          const Offset(60, 10),
          const Duration(milliseconds: 170),
        );
        expect(fastMove, [isA<TwoFingerScrollEndResult>()]);

        final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 180));
        expect(upResult, [isA<TwoFingerSwipeResult>()]);
      });

      test('short quick movement below min distance is treated as scroll, not swipe', () {
        recognizer.onPointerDown(1, const Offset(10, 10), const Duration(milliseconds: 0));
        recognizer.onPointerDown(2, const Offset(50, 50), const Duration(milliseconds: 50));

        // 5px を 4ms で動かすと速いが、重心移動は 2.5px で最小距離未満
        recognizer.onPointerMove(1, const Offset(15, 10), const Duration(milliseconds: 54));
        recognizer.onPointerMove(2, const Offset(55, 50), const Duration(milliseconds: 54));

        final upResult = recognizer.onPointerUp(1, const Duration(milliseconds: 60));
        expect(upResult, [isA<TwoFingerScrollEndResult>()]);
      });
    });
  });
}
