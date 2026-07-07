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

class RightClickResult extends TouchpadGestureResult {
  const RightClickResult();
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

/// 2本指でのスクロール/ピンチ操作の開始。実際にスクロールかピンチかは
/// 外部ディスプレイ側のアプリが2点の生の動きから判断するため、ここでは
/// 「2本指が動き始めた」ことだけを表す(単一責任: 分類しない)。
class TwoFingerMoveStartResult extends TouchpadGestureResult {
  const TwoFingerMoveStartResult();
}

/// 2本指のうち片方の指の移動量。[isPrimary] で1本目/2本目を区別する。
class TwoFingerMoveResult extends TouchpadGestureResult {
  const TwoFingerMoveResult(this.isPrimary, this.dx, this.dy);
  final bool isPrimary;
  final double dx;
  final double dy;
}

class TwoFingerMoveEndResult extends TouchpadGestureResult {
  const TwoFingerMoveEndResult();
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
/// - 指を置いてから **動かさずに離した場合のみ** タップ(左クリック)として扱う。
/// - 指を置いた直後に動かした場合は、動いた瞬間から常にカーソル移動として扱い、
///   その後どれだけ早く離してもクリックにはならない(移動とタップは常に排他)。
/// - 指を動かさずにその場で一定時間(長押し時間設定)保持し続けると、その後の移動は
///   再タッチなしで直接ドラッグになる([onLongPressTimeout] 経由、呼び出し側のタイマーで検知)。
///   動かさずに離せば右クリック相当になる。
/// - 2本指を同時に置いて短時間で離すと右クリック(既存仕様のまま)。
/// - タップ直後の再タッチによるドラッグは削除済み。再タッチは独立した操作として扱う。
///
/// Flutter の Widget/BuildContext/MethodChannel に依存しない純 Dart クラスで、ユニットテスト可能。
class TouchpadGestureRecognizer {
  TouchpadGestureRecognizer({
    this.tapMaxDuration = const Duration(milliseconds: 220),
    this.tapSlop = 12.0,
    this.twoFingerWindow = const Duration(milliseconds: 150),
    this.twoFingerTapMaxDuration = const Duration(milliseconds: 400),
  });

  final Duration tapMaxDuration;
  final double tapSlop;
  final Duration twoFingerWindow;
  final Duration twoFingerTapMaxDuration;

  _Phase _phase = _Phase.idle;
  final Map<int, _PointerTrack> _pointers = {};
  Duration _phaseStartTime = Duration.zero;
  bool _phaseMoved = false;

  /// 2本指ジェスチャ中、1本目として置かれた指の pointerId。
  /// [TwoFingerMoveResult.isPrimary] の判定にのみ使う。
  int? _twoFingerPrimaryId;

  /// 指を動かさずに一定時間その場に留まり続けた場合に呼ぶ(実際の経過時間の計測は
  /// 呼び出し側の [Timer] が担う。純 Dart の本クラスは自前の時計を持たないため)。
  /// 静止したまま保持し続けた指はドラッグ武装状態になり、その後移動すればドラッグに、
  /// 動かさずに離せば右クリック相当になる(2本指タップと同じ意図の代替手段)。
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
        if (becomesTwoFinger) _twoFingerPrimaryId = _pointers.keys.single;
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
          // 2本指が動いた: スクロールかピンチかはここでは判定せず、
          // 生の2点の動きとして外部ディスプレイ側へそのまま転送する
          // (先方のアプリが本物のタッチと同様に解釈する)。
          _phaseMoved = true;
          _phase = _Phase.twoFingerMoving;
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          final isPrimary = pointerId == _twoFingerPrimaryId;
          return [
            const TwoFingerMoveStartResult(),
            TwoFingerMoveResult(isPrimary, moveDelta.dx, moveDelta.dy),
          ];
        }

      case _Phase.twoFingerMoving:
        {
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          final isPrimary = pointerId == _twoFingerPrimaryId;
          return [TwoFingerMoveResult(isPrimary, moveDelta.dx, moveDelta.dy)];
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
      return const [TwoFingerMoveEndResult()];
    }

    if (_phase == _Phase.twoFinger) {
      // 2本指を置いてすぐ離した場合は右クリック + 終了イベント。
      // 片方だけ離れた場合は残りの指がいるため dead へ遷移し、終了イベントを発行する。
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      final held = timestamp - _phaseStartTime;
      if (!_phaseMoved && held < twoFingerTapMaxDuration) {
        return const [RightClickResult(), TwoFingerMoveEndResult()];
      }
      return const [TwoFingerMoveEndResult()];
    }

    if (_pointers.isNotEmpty) return const [];

    final phase = _phase;
    final moved = _phaseMoved;
    final held = timestamp - _phaseStartTime;
    _phase = _Phase.idle;
    _phaseMoved = false;

    switch (phase) {
      case _Phase.single:
        // 動かさずに短時間保持の場合のみ左クリック。
        if (!moved && held < tapMaxDuration) return const [LeftClickResult()];
        return const [];
      case _Phase.longPressArmed:
        // 静止したまま長押しを離した場合は右クリック相当(2本指タップと同じ意味)。
        // 移動していれば onPointerMove で既に _Phase.dragging へ遷移しているため、
        // ここに来る時点で必ず未移動である。
        return const [RightClickResult()];
      case _Phase.dragging:
        return const [DragEndResult()];
      case _Phase.twoFinger:
      case _Phase.twoFingerMoving:
      case _Phase.idle:
      case _Phase.dead:
        return const [];
    }
  }

  void onPointerCancel(int pointerId) {
    final wasTwoFingerMoving = _phase == _Phase.twoFingerMoving;
    _pointers.remove(pointerId);
    if (wasTwoFingerMoving) {
      _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
      _phaseMoved = false;
      return;
    }
    if (_pointers.isEmpty) {
      _phase = _Phase.idle;
      _phaseMoved = false;
    }
  }
}
