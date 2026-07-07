import 'dart:ui' show Offset;

/// タッチパッドのジェスチャ認識結果(仕様 §6)。
/// フレーム単位への集約は呼び出し側([TouchpadController])の責務であり、
/// ここでは生デルタのみを渡す(単一責任)。
sealed class TouchpadGestureResult {
  const TouchpadGestureResult();
}

class CursorMoveResult extends TouchpadGestureResult {
  const CursorMoveResult(this.dx, this.dy);
  final double dx;
  final double dy;
}

class LeftClickResult extends TouchpadGestureResult {
  const LeftClickResult();
}

/// 指を動かさずに長押しして、動かさずに離した場合の長押し操作
/// (Android のマウスには右クリックが無いため、右クリックの代替として
/// 「その場での長押しタップ」を外部ディスプレイに送る)。
class LongPressResult extends TouchpadGestureResult {
  const LongPressResult();
}

/// 長押し後のドラッグ開始を表す。
class DragStartResult extends TouchpadGestureResult {
  const DragStartResult();
}

class DragMoveResult extends TouchpadGestureResult {
  const DragMoveResult(this.dx, this.dy);
  final double dx;
  final double dy;
}

class DragEndResult extends TouchpadGestureResult {
  const DragEndResult();
}

/// 2本指スワイプの開始。
class TwoFingerSwipeStartResult extends TouchpadGestureResult {
  const TwoFingerSwipeStartResult();
}

/// 2本指の重心(センターポイント)の移動量。2本指は常に同じ量だけ動かして
/// 外部ディスプレイへ転送するため(単一責任: ここでピンチかスワイプかを
/// 判定しない代わりに、そもそも間隔が変化しない=ピンチが起こり得ない設計にする)。
class TwoFingerSwipeMoveResult extends TouchpadGestureResult {
  const TwoFingerSwipeMoveResult(this.dx, this.dy);
  final double dx;
  final double dy;
}

class TwoFingerSwipeEndResult extends TouchpadGestureResult {
  const TwoFingerSwipeEndResult();
}

enum _Phase { idle, single, longPressArmed, dragging, twoFinger, twoFingerMoving, dead }

class _PointerTrack {
  _PointerTrack(Offset position) : downPosition = position, lastPosition = position;
  final Offset downPosition;
  Offset lastPosition;
}

/// ノートパソコンのクリックパッドと同じ操作感を目指した状態機械。
///
/// 方針(矛盾を避けるための唯一のルール):
/// - 指を置いてから **動かさずに素早く離した場合のみ** タップ(クリック)として扱う。
/// - 指を置いた直後に動かした場合は、動いた瞬間から常にカーソル移動として扱い、
///   その後どれだけ早く離してもクリックにはならない(移動とタップは常に排他)。
/// - 指を動かさずにその場で一定時間(長押し時間設定)保持し続けると、その後の移動は
///   再タッチなしで直接ドラッグになる([onLongPressTimeout] 経由、呼び出し側のタイマーで検知)。
///   動かさずに離せば長押し操作になる。
/// - 2本指は常にスワイプとして扱う。ピンチ・右クリックは存在しない(Android のマウス
///   カーソルに右クリックが無いことに合わせて廃止)。
///
/// Flutter の Widget/BuildContext/MethodChannel に依存しない純 Dart クラスで、ユニットテスト可能。
class TouchpadGestureRecognizer {
  TouchpadGestureRecognizer({
    this.tapMaxDuration = const Duration(milliseconds: 220),
    this.tapSlop = 12.0,
    this.twoFingerWindow = const Duration(milliseconds: 150),
  });

  final Duration tapMaxDuration;
  final double tapSlop;
  final Duration twoFingerWindow;

  _Phase _phase = _Phase.idle;
  final Map<int, _PointerTrack> _pointers = {};
  Duration _phaseStartTime = Duration.zero;
  bool _phaseMoved = false;

  /// 指を動かさずに一定時間その場に留まり続けた場合に呼ぶ(実際の経過時間の計測は
  /// 呼び出し側の [Timer] が担う。純 Dart の本クラスは自前の時計を持たないため)。
  /// 静止したまま保持し続けた指はドラッグ武装状態になり、その後移動すればドラッグに、
  /// 動かさずに離せば長押し操作になる。
  List<TouchpadGestureResult> onLongPressTimeout(int pointerId) {
    if (_phase != _Phase.single) return const [];
    if (_phaseMoved) return const [];
    if (_pointers.length != 1 || !_pointers.containsKey(pointerId)) return const [];
    _phase = _Phase.longPressArmed;
    return const [];
  }

  List<TouchpadGestureResult> onPointerDown(int pointerId, Offset position, Duration timestamp) {
    switch (_phase) {
      case _Phase.idle:
        _pointers[pointerId] = _PointerTrack(position);
        _phase = _Phase.single;
        _phaseStartTime = timestamp;
        _phaseMoved = false;
        return const [];

      case _Phase.single:
      case _Phase.longPressArmed:
        final withinWindow = timestamp - _phaseStartTime <= twoFingerWindow;
        final becomesTwoFinger = withinWindow && !_phaseMoved;
        _pointers[pointerId] = _PointerTrack(position);
        _phase = becomesTwoFinger ? _Phase.twoFinger : _Phase.dead;
        return const [];

      case _Phase.dragging:
      case _Phase.twoFinger:
      case _Phase.twoFingerMoving:
      case _Phase.dead:
        _pointers[pointerId] = _PointerTrack(position);
        _phase = _Phase.dead;
        return const [];
    }
  }

  List<TouchpadGestureResult> onPointerMove(int pointerId, Offset position, Duration timestamp) {
    final track = _pointers[pointerId];
    if (track == null) return const [];

    switch (_phase) {
      case _Phase.single:
        {
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          if (!_phaseMoved) {
            final movedNow = (position - track.downPosition).distance > tapSlop;
            if (!movedNow) return const [];
            _phaseMoved = true;
          }
          // 動いた瞬間からタップの可能性は消え、常にカーソル移動として扱う。
          return [CursorMoveResult(moveDelta.dx, moveDelta.dy)];
        }

      case _Phase.longPressArmed:
        {
          // 長押し後はわずかな動きでも即座にドラッグ開始。tapSlop の判定は不要。
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          _phase = _Phase.dragging;
          return [
            const DragStartResult(),
            DragMoveResult(moveDelta.dx, moveDelta.dy),
          ];
        }

      case _Phase.dragging:
        {
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          return [DragMoveResult(moveDelta.dx, moveDelta.dy)];
        }

      case _Phase.twoFinger:
        {
          if ((position - track.downPosition).distance <= tapSlop) {
            track.lastPosition = position;
            return const [];
          }
          // 2本指が動き始めた: スワイプとして扱う。
          _phaseMoved = true;
          _phase = _Phase.twoFingerMoving;
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          return [
            const TwoFingerSwipeStartResult(),
            TwoFingerSwipeMoveResult(moveDelta.dx / 2, moveDelta.dy / 2),
          ];
        }

      case _Phase.twoFingerMoving:
        {
          // 重心(2点の平均)の移動量として扱う: どちらの指が動いても、
          // その半分をスワイプ量として送る(2指とも動けば合計で実距離分になる)。
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          return [TwoFingerSwipeMoveResult(moveDelta.dx / 2, moveDelta.dy / 2)];
        }

      case _Phase.idle:
      case _Phase.dead:
        track.lastPosition = position;
        return const [];
    }
  }

  List<TouchpadGestureResult> onPointerUp(int pointerId, Duration timestamp) {
    final track = _pointers.remove(pointerId);
    if (track == null) return const [];

    // 2本指ジェスチャー中は、どちらか一方が離れた時点で即座に終了する
    // (実際のトラックパッドと同じく、指の本数が減った瞬間に終わる)。
    if (_phase == _Phase.twoFingerMoving) {
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      return const [TwoFingerSwipeEndResult()];
    }

    if (_phase == _Phase.twoFinger) {
      // 2本指を置いてすぐ離した場合は何もしない(右クリックは廃止)。
      // 片方だけ離れた場合は残りの指がいるため dead へ遷移する。
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      return const [];
    }

    if (_pointers.isNotEmpty) return const [];

    final phase = _phase;
    final moved = _phaseMoved;
    final held = timestamp - _phaseStartTime;
    _phase = _Phase.idle;
    _phaseMoved = false;

    switch (phase) {
      case _Phase.single:
        // 動かさずに素早く離した場合のみクリック。
        if (!moved && held < tapMaxDuration) return const [LeftClickResult()];
        return const [];
      case _Phase.longPressArmed:
        // 静止したまま長押しを離した場合は長押し操作。
        // 移動していれば onPointerMove で既に _Phase.dragging へ遷移しているため、
        // ここに来る時点で必ず未移動である。
        return const [LongPressResult()];
      case _Phase.dragging:
        return const [DragEndResult()];
      case _Phase.twoFinger:
      case _Phase.twoFingerMoving:
      case _Phase.idle:
      case _Phase.dead:
        return const [];
    }
  }

  /// システムがジェスチャーを中断した場合(Android が `ACTION_CANCEL` を配送した場合等)。
  /// ドラッグ中/2本指スワイプ中にキャンセルされた場合は、[onPointerUp] と同じ終了結果を
  /// 返して呼び出し側がネイティブ側のジェスチャー状態を確実に解放できるようにする。
  /// これを怠ると、ネイティブ側の直列化ガードが解除されないまま永久に「busy」となり、
  /// 以後のあらゆる操作が効かなくなる(実機で確認された不具合の根本原因)。
  List<TouchpadGestureResult> onPointerCancel(int pointerId) {
    final hadPointer = _pointers.remove(pointerId) != null;
    if (!hadPointer) return const [];

    if (_phase == _Phase.dragging) {
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      return const [DragEndResult()];
    }

    if (_phase == _Phase.twoFingerMoving || _phase == _Phase.twoFinger) {
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      return const [TwoFingerSwipeEndResult()];
    }

    if (_pointers.isEmpty) {
      _phase = _Phase.idle;
      _phaseMoved = false;
    }
    return const [];
  }
}
