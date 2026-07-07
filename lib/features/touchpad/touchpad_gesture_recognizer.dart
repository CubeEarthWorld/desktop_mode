import 'dart:ui' show Offset;

/// タッチパッドのジェスチャ認識結果。
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

/// 2本指スクロールの開始。
class TwoFingerScrollStartResult extends TouchpadGestureResult {
  const TwoFingerScrollStartResult();
}

/// 2本指の重心(センターポイント)の移動量。2本指は常に同じ量だけ動かして
/// 外部ディスプレイへ転送するため(単一責任: ここでピンチかスワイプかを
/// 判定しない代わりに、そもそも間隔が変化しない=ピンチが起こり得ない設計にする)。
class TwoFingerScrollMoveResult extends TouchpadGestureResult {
  const TwoFingerScrollMoveResult(this.dx, this.dy);
  final double dx;
  final double dy;
}

class TwoFingerScrollEndResult extends TouchpadGestureResult {
  const TwoFingerScrollEndResult();
}

/// 2本指の素早いスワイプ（フリック）を表す。
/// [dx]/[dy] は2本指の重心の総移動量で、スワイプ方向を表す。
class TwoFingerSwipeResult extends TouchpadGestureResult {
  const TwoFingerSwipeResult(this.dx, this.dy);
  final double dx;
  final double dy;
}

enum _Phase {
  idle,
  single,
  dragging,
  twoFinger,
  twoFingerScroll,
  twoFingerSwipe,
  dead,
}

class _PointerTrack {
  _PointerTrack(Offset position)
    : downPosition = position,
      lastPosition = position,
      accumulatedDistance = 0;
  final Offset downPosition;
  Offset lastPosition;
  double accumulatedDistance;
}

/// ノートパソコンのクリックパッドと同じ操作感を目指した状態機械。
///
/// 方針(矛盾を避けるための唯一のルール):
/// - **クリック判定は指を離したタイミングで行う。**
///   1本指を置いて動かさずに素早く離した場合のみ左クリック、
///   動かさずに長押し時間以上保持して離した場合は右クリック相当の長押し、
///   長押し時間を超えてから動かした場合はドラッグとなる。
/// - 指を置いた直後に動かした場合は、動いた瞬間から常にカーソル移動として扱い、
///   その後どれだけ早く離してもクリックにはならない(移動とタップは常に排他)。
/// - 2本指は「ゆっくり動かしたらスクロール、素早くスライドして離したらスワイプ」
///   として扱う。速度判定は重心の瞬間速度で行う。
/// - 2本指タップ(右クリック相当)・ピンチは存在しない
///   (Android のマウスカーソルに右クリックが無いことに合わせて廃止)。
/// - 2本目の指を置く際、1本目がわずかに動いていても時間窓内なら2本指として認識する。
///   これは、指を置く瞬間の震えや2本目を置くときの位置調整で1本目が動いてしまい、
///   結果的に2本指スクロールが1本指のカーソル移動と誤認識されるのを防ぐため。
///
/// Flutter の Widget/BuildContext/MethodChannel に依存しない純 Dart クラスで、ユニットテスト可能。
class TouchpadGestureRecognizer {
  TouchpadGestureRecognizer({
    this.tapMaxDuration = const Duration(milliseconds: 220),
    this.tapSlop = 12.0,
    // 実機で2本目の指を置くのに150msでは短すぎて2本指が認識されず、
    // 1本指のカーソル移動/タップと誤認識されることがあったため、
    // 人間の指の動きに余裕を持たせて350msに緩和する。
    this.twoFingerWindow = const Duration(milliseconds: 350),
    this.swipeMinVelocity = 1.0,
    this.swipeMinDistance = 24.0,
  });

  final Duration tapMaxDuration;
  final double tapSlop;
  final Duration twoFingerWindow;

  /// 2本指ジェスチャをスワイプとみなす最小の重心速度（logical px / ms）。
  final double swipeMinVelocity;

  /// 2本指ジェスチャをスワイプとみなす最小の重心移動距離（logical px）。
  final double swipeMinDistance;

  _Phase _phase = _Phase.idle;
  final Map<int, _PointerTrack> _pointers = {};

  // single / dragging 用
  Duration _singleStartTime = Duration.zero;
  bool _singleMoved = false;
  bool _singleLongPressElapsed = false;

  // 2本指用
  Offset _twoFingerStartCentroid = Offset.zero;
  Offset _twoFingerLastCentroid = Offset.zero;
  Duration _twoFingerLastTime = Duration.zero;
  bool _twoFingerScrollStarted = false;
  bool _twoFingerSwipeDetected = false;
  double _twoFingerTotalDistance = 0;

  /// 指を動かさずに一定時間その場に留まり続けた場合に呼ぶ(実際の経過時間の計測は
  /// 呼び出し側の [Timer] が担う。純 Dart の本クラスは自前の時計を持たないため)。
  /// 静止したまま保持し続けた指はドラッグ/長押し判定の閾値を超えた状態となり、
  /// その後移動すればドラッグに、動かさず離せば長押し操作になる。
  List<TouchpadGestureResult> onLongPressTimeout(int pointerId) {
    if (_phase != _Phase.single) return const [];
    if (_singleMoved) return const [];
    if (_pointers.length != 1 || !_pointers.containsKey(pointerId)) return const [];
    _singleLongPressElapsed = true;
    return const [];
  }

  List<TouchpadGestureResult> onPointerDown(int pointerId, Offset position, Duration timestamp) {
    switch (_phase) {
      case _Phase.idle:
        _pointers[pointerId] = _PointerTrack(position);
        _phase = _Phase.single;
        _singleStartTime = timestamp;
        _singleMoved = false;
        _singleLongPressElapsed = false;
        return const [];

      case _Phase.single:
        final withinWindow = timestamp - _singleStartTime <= twoFingerWindow;
        // 1本目の指がわずかに動いていても、累積移動距離が tapSlop 未満なら2本指として
        // 認識する。指を置く瞬間の震えや2本目を置くときの位置調整を許容する。
        final firstPointer = _pointers.values.first;
        final onlyNudged = firstPointer.accumulatedDistance <= tapSlop;
        final becomesTwoFinger = withinWindow && onlyNudged;
        _pointers[pointerId] = _PointerTrack(position);
        if (becomesTwoFinger) {
          _phase = _Phase.twoFinger;
          _initTwoFingerTracking(timestamp);
        } else {
          _phase = _Phase.dead;
        }
        return const [];

      case _Phase.dragging:
      case _Phase.twoFinger:
      case _Phase.twoFingerScroll:
      case _Phase.twoFingerSwipe:
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
          track.accumulatedDistance += moveDelta.distance;

          if (_singleLongPressElapsed) {
            // 長押し時間を超えてから動いたら即座にドラッグ開始。
            _phase = _Phase.dragging;
            return [
              const DragStartResult(),
              DragMoveResult(moveDelta.dx, moveDelta.dy),
            ];
          }

          if (!_singleMoved) {
            final movedNow = (position - track.downPosition).distance > tapSlop;
            if (!movedNow) return const [];
            _singleMoved = true;
          }
          // 動いた瞬間からタップ/長押しの可能性は消え、常にカーソル移動として扱う。
          return [CursorMoveResult(moveDelta.dx, moveDelta.dy)];
        }

      case _Phase.dragging:
        {
          final moveDelta = position - track.lastPosition;
          track.lastPosition = position;
          track.accumulatedDistance += moveDelta.distance;
          return [DragMoveResult(moveDelta.dx, moveDelta.dy)];
        }

      case _Phase.twoFinger:
        {
          _updateTrack(track, position);
          return _handleTwoFingerFirstMove(timestamp);
        }

      case _Phase.twoFingerScroll:
        {
          _updateTrack(track, position);
          return _handleTwoFingerScrollMove(timestamp);
        }

      case _Phase.twoFingerSwipe:
        {
          _updateTrack(track, position);
          final centroid = _centroid();
          _twoFingerLastCentroid = centroid;
          _twoFingerLastTime = timestamp;
          return const [];
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

    switch (_phase) {
      case _Phase.twoFingerSwipe:
        {
          final results = <TouchpadGestureResult>[];
          if (_twoFingerSwipeDetected) {
            results.add(TwoFingerSwipeResult(
              _twoFingerLastCentroid.dx - _twoFingerStartCentroid.dx,
              _twoFingerLastCentroid.dy - _twoFingerStartCentroid.dy,
            ));
          }
          _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
          _resetTwoFingerTracking();
          return results;
        }

      case _Phase.twoFingerScroll:
        {
          _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
          _resetTwoFingerTracking();
          return const [TwoFingerScrollEndResult()];
        }

      case _Phase.twoFinger:
        {
          // 2本指を置いてすぐ離した場合は何もしない(右クリックは廃止)。
          // 片方だけ離れた場合は残りの指がいるため dead へ遷移する。
          _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
          _resetTwoFingerTracking();
          return const [];
        }

      case _Phase.single:
        {
          if (_pointers.isNotEmpty) return const [];
          final moved = _singleMoved;
          final longPressElapsed = _singleLongPressElapsed;
          final held = timestamp - _singleStartTime;
          _phase = _Phase.idle;
          _resetSingleTracking();

          // クリック/長押しの判定は離すタイミングで行う。
          if (longPressElapsed && !moved) return const [LongPressResult()];
          if (!moved && held < tapMaxDuration) return const [LeftClickResult()];
          return const [];
        }

      case _Phase.dragging:
        {
          if (_pointers.isNotEmpty) return const [];
          _phase = _Phase.idle;
          return const [DragEndResult()];
        }

      case _Phase.dead:
        {
          if (_pointers.isEmpty) _phase = _Phase.idle;
          return const [];
        }

      case _Phase.idle:
        return const [];
    }
  }

  /// システムがジェスチャーを中断した場合(Android が `ACTION_CANCEL` を配送した場合等)。
  /// ドラッグ中/2本指スクロール中にキャンセルされた場合は、[onPointerUp] と同じ終了結果を
  /// 返して呼び出し側がネイティブ側のジェスチャー状態を確実に解放できるようにする。
  /// これを怠ると、ネイティブ側の直列化ガードが解除されないまま永久に「busy」となり、
  /// 以後のあらゆる操作が効かなくなる(実機で確認された不具合の根本原因)。
  List<TouchpadGestureResult> onPointerCancel(int pointerId) {
    final hadPointer = _pointers.remove(pointerId) != null;
    if (!hadPointer) return const [];

    switch (_phase) {
      case _Phase.dragging:
        _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
        return const [DragEndResult()];

      case _Phase.twoFingerScroll:
      case _Phase.twoFingerSwipe:
        {
          final shouldEndScroll = _twoFingerScrollStarted;
          _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
          _resetTwoFingerTracking();
          return shouldEndScroll ? const [TwoFingerScrollEndResult()] : const [];
        }

      case _Phase.twoFinger:
        _phase = _pointers.isEmpty ? _Phase.idle : _Phase.dead;
        _resetTwoFingerTracking();
        return const [];

      case _Phase.single:
      case _Phase.dead:
        if (_pointers.isEmpty) _phase = _Phase.idle;
        return const [];

      case _Phase.idle:
        return const [];
    }
  }

  /// 診断用: 現在の相を文字列で取得する。
  String get currentPhaseName => _phase.name;

  void _resetSingleTracking() {
    _singleMoved = false;
    _singleLongPressElapsed = false;
  }

  void _initTwoFingerTracking(Duration timestamp) {
    _twoFingerStartCentroid = _centroid();
    _twoFingerLastCentroid = _twoFingerStartCentroid;
    _twoFingerLastTime = timestamp;
    _twoFingerScrollStarted = false;
    _twoFingerSwipeDetected = false;
    _twoFingerTotalDistance = 0;
  }

  void _resetTwoFingerTracking() {
    _twoFingerStartCentroid = Offset.zero;
    _twoFingerLastCentroid = Offset.zero;
    _twoFingerLastTime = Duration.zero;
    _twoFingerScrollStarted = false;
    _twoFingerSwipeDetected = false;
    _twoFingerTotalDistance = 0;
  }

  void _updateTrack(_PointerTrack track, Offset position) {
    final delta = position - track.lastPosition;
    track.lastPosition = position;
    track.accumulatedDistance += delta.distance;
  }

  Offset _centroid() {
    if (_pointers.isEmpty) return Offset.zero;
    double x = 0;
    double y = 0;
    for (final track in _pointers.values) {
      x += track.lastPosition.dx;
      y += track.lastPosition.dy;
    }
    return Offset(x / _pointers.length, y / _pointers.length);
  }

  List<TouchpadGestureResult> _handleTwoFingerFirstMove(Duration timestamp) {
    final centroid = _centroid();
    final centroidDelta = centroid - _twoFingerLastCentroid;
    final dtMs = (timestamp - _twoFingerLastTime).inMilliseconds;
    final velocity = dtMs > 0 ? centroidDelta.distance / dtMs : 0.0;

    _twoFingerLastCentroid = centroid;
    _twoFingerLastTime = timestamp;
    _twoFingerTotalDistance += centroidDelta.distance;

    if (velocity >= swipeMinVelocity && _twoFingerTotalDistance >= swipeMinDistance) {
      _phase = _Phase.twoFingerSwipe;
      _twoFingerSwipeDetected = true;
      return const [];
    }

    _phase = _Phase.twoFingerScroll;
    _twoFingerScrollStarted = true;
    return [
      const TwoFingerScrollStartResult(),
      TwoFingerScrollMoveResult(centroidDelta.dx, centroidDelta.dy),
    ];
  }

  List<TouchpadGestureResult> _handleTwoFingerScrollMove(Duration timestamp) {
    final centroid = _centroid();
    final centroidDelta = centroid - _twoFingerLastCentroid;
    final dtMs = (timestamp - _twoFingerLastTime).inMilliseconds;
    final velocity = dtMs > 0 ? centroidDelta.distance / dtMs : 0.0;

    _twoFingerLastCentroid = centroid;
    _twoFingerLastTime = timestamp;
    _twoFingerTotalDistance += centroidDelta.distance;

    if (velocity >= swipeMinVelocity && _twoFingerTotalDistance >= swipeMinDistance) {
      _phase = _Phase.twoFingerSwipe;
      _twoFingerSwipeDetected = true;
      return const [TwoFingerScrollEndResult()];
    }

    return [TwoFingerScrollMoveResult(centroidDelta.dx, centroidDelta.dy)];
  }
}
