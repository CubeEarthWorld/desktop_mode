import 'dart:ui' show Offset;

enum TouchpadPhase {
  idle,
  oneFingerPending,
  cursorMoving,
  dragArmed,
  dragging,
  twoFingerPending,
  scrolling,
  suppressed,
}

sealed class TouchpadGestureResult {
  const TouchpadGestureResult(this.sessionId);

  final int sessionId;
}

class CursorMoveResult extends TouchpadGestureResult {
  const CursorMoveResult(super.sessionId, this.dx, this.dy);

  final double dx;
  final double dy;
}

class LeftClickResult extends TouchpadGestureResult {
  const LeftClickResult(super.sessionId);
}

class LongPressResult extends TouchpadGestureResult {
  const LongPressResult(super.sessionId);
}

enum ContinuousGestureKind { drag, scroll }

class ContinuousGestureStartResult extends TouchpadGestureResult {
  const ContinuousGestureStartResult(super.sessionId, this.kind);

  final ContinuousGestureKind kind;
}

class ContinuousGestureMoveResult extends TouchpadGestureResult {
  const ContinuousGestureMoveResult(
    super.sessionId,
    this.kind,
    this.dx,
    this.dy,
  );

  final ContinuousGestureKind kind;
  final double dx;
  final double dy;
}

class ContinuousGestureEndResult extends TouchpadGestureResult {
  const ContinuousGestureEndResult(
    super.sessionId,
    this.kind, {
    required this.cancelled,
  });

  final ContinuousGestureKind kind;
  final bool cancelled;
}

class _PointerTrack {
  _PointerTrack(Offset position)
    : downPosition = position,
      lastPosition = position;

  final Offset downPosition;
  Offset lastPosition;
}

/// A deterministic gesture arena for the whole physical touch session.
///
/// A session starts with the first pointer down and is not reusable until all
/// pointers have left. The recognizer emits semantic actions only; platform
/// calls and timers are owned by the controller.
class TouchpadGestureRecognizer {
  TouchpadGestureRecognizer({
    this.tapMaxDuration = const Duration(milliseconds: 250),
    this.tapSlop = 12.0,
    this.dragActivationSlop = 1.0,
    this.twoFingerSlop = 12.0,
  });

  final Duration tapMaxDuration;
  final double tapSlop;
  final double dragActivationSlop;
  final double twoFingerSlop;

  static int _nextGlobalSessionId = 1;

  final Map<int, _PointerTrack> _pointers = {};
  TouchpadPhase _phase = TouchpadPhase.idle;
  int? _sessionId;
  Duration _sessionStartTime = Duration.zero;
  Offset? _dragArmedOrigin;
  Offset? _twoFingerOrigin;
  Offset? _twoFingerLast;

  TouchpadPhase get phase => _phase;
  int? get sessionId => _sessionId;
  int get pointerCount => _pointers.length;

  List<TouchpadGestureResult> onPointerDown(
    int pointerId,
    Offset position,
    Duration timestamp,
  ) {
    if (_pointers.containsKey(pointerId)) {
      return _suppress(cancelActive: true);
    }

    if (_phase == TouchpadPhase.idle) {
      _sessionId = _nextGlobalSessionId++;
      _sessionStartTime = timestamp;
      _pointers[pointerId] = _PointerTrack(position);
      _phase = TouchpadPhase.oneFingerPending;
      return const [];
    }

    _pointers[pointerId] = _PointerTrack(position);

    if (_phase == TouchpadPhase.suppressed) return const [];

    if (_phase == TouchpadPhase.dragging || _phase == TouchpadPhase.scrolling) {
      return _suppress(cancelActive: true);
    }

    if (_pointers.length == 2 &&
        (_phase == TouchpadPhase.oneFingerPending ||
            _phase == TouchpadPhase.cursorMoving ||
            _phase == TouchpadPhase.dragArmed)) {
      _phase = TouchpadPhase.twoFingerPending;
      _dragArmedOrigin = null;
      final centroid = _centroid();
      _twoFingerOrigin = centroid;
      _twoFingerLast = centroid;
      return const [];
    }

    return _suppress(cancelActive: false);
  }

  List<TouchpadGestureResult> onPointerMove(
    int pointerId,
    Offset position,
    Duration timestamp,
  ) {
    final track = _pointers[pointerId];
    if (track == null) return const [];

    final previous = track.lastPosition;
    track.lastPosition = position;
    final id = _sessionId;
    if (id == null) return const [];

    switch (_phase) {
      case TouchpadPhase.oneFingerPending:
        if ((position - track.downPosition).distance <= tapSlop) {
          return const [];
        }
        _phase = TouchpadPhase.cursorMoving;
        final delta = position - track.downPosition;
        return [CursorMoveResult(id, delta.dx, delta.dy)];

      case TouchpadPhase.cursorMoving:
        final delta = position - previous;
        return _nonZeroCursorResult(id, delta);

      case TouchpadPhase.dragArmed:
        final origin = _dragArmedOrigin ?? previous;
        if ((position - origin).distance <= dragActivationSlop) return const [];
        _phase = TouchpadPhase.dragging;
        final delta = position - origin;
        return [
          ContinuousGestureStartResult(id, ContinuousGestureKind.drag),
          ContinuousGestureMoveResult(
            id,
            ContinuousGestureKind.drag,
            delta.dx,
            delta.dy,
          ),
        ];

      case TouchpadPhase.dragging:
        final delta = position - previous;
        return _nonZeroContinuousResult(id, ContinuousGestureKind.drag, delta);

      case TouchpadPhase.twoFingerPending:
        final centroid = _centroid();
        final origin = _twoFingerOrigin;
        if (centroid == null || origin == null) return const [];
        _twoFingerLast = centroid;
        if ((centroid - origin).distance <= twoFingerSlop) return const [];
        _phase = TouchpadPhase.scrolling;
        final delta = centroid - origin;
        return [
          ContinuousGestureStartResult(id, ContinuousGestureKind.scroll),
          ContinuousGestureMoveResult(
            id,
            ContinuousGestureKind.scroll,
            delta.dx,
            delta.dy,
          ),
        ];

      case TouchpadPhase.scrolling:
        final centroid = _centroid();
        final last = _twoFingerLast;
        if (centroid == null || last == null) return const [];
        _twoFingerLast = centroid;
        return _nonZeroContinuousResult(
          id,
          ContinuousGestureKind.scroll,
          centroid - last,
        );

      case TouchpadPhase.idle:
      case TouchpadPhase.suppressed:
        return const [];
    }
  }

  /// Arms dragging only when this timer still belongs to the pending session.
  List<TouchpadGestureResult> onLongPressTimeout(
    int pointerId,
    int expectedSessionId,
  ) {
    if (_phase != TouchpadPhase.oneFingerPending ||
        _sessionId != expectedSessionId ||
        _pointers.length != 1) {
      return const [];
    }
    final track = _pointers[pointerId];
    if (track == null ||
        (track.lastPosition - track.downPosition).distance > tapSlop) {
      return const [];
    }
    _dragArmedOrigin = track.lastPosition;
    _phase = TouchpadPhase.dragArmed;
    return const [];
  }

  List<TouchpadGestureResult> onPointerUp(
    int pointerId,
    Offset position,
    Duration timestamp,
  ) {
    // Flutter can report the last physical displacement only on PointerUpEvent.
    // Classify that displacement before removing the pointer so an armed drag
    // cannot accidentally commit as a long press.
    final moveResults = onPointerMove(pointerId, position, timestamp);
    final track = _pointers.remove(pointerId);
    final id = _sessionId;
    if (track == null || id == null) return const [];

    switch (_phase) {
      case TouchpadPhase.oneFingerPending:
        final held = timestamp - _sessionStartTime;
        final isTap =
            _pointers.isEmpty &&
            held <= tapMaxDuration &&
            (track.lastPosition - track.downPosition).distance <= tapSlop;
        _finishIfEmpty();
        return isTap ? [...moveResults, LeftClickResult(id)] : moveResults;

      case TouchpadPhase.cursorMoving:
        _finishIfEmpty();
        return moveResults;

      case TouchpadPhase.dragArmed:
        final commitsLongPress = _pointers.isEmpty;
        _finishIfEmpty();
        return commitsLongPress
            ? [...moveResults, LongPressResult(id)]
            : moveResults;

      case TouchpadPhase.dragging:
        final result = ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.drag,
          cancelled: false,
        );
        _finishOrSuppress();
        return [...moveResults, result];

      case TouchpadPhase.twoFingerPending:
        _finishOrSuppress();
        return moveResults;

      case TouchpadPhase.scrolling:
        final result = ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.scroll,
          cancelled: false,
        );
        _finishOrSuppress();
        return [...moveResults, result];

      case TouchpadPhase.suppressed:
        _finishIfEmpty();
        return moveResults;

      case TouchpadPhase.idle:
        return const [];
    }
  }

  List<TouchpadGestureResult> onPointerCancel(int pointerId) {
    final removed = _pointers.remove(pointerId);
    final id = _sessionId;
    if (removed == null || id == null) return const [];

    final results = switch (_phase) {
      TouchpadPhase.dragging => <TouchpadGestureResult>[
        ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.drag,
          cancelled: true,
        ),
      ],
      TouchpadPhase.scrolling => <TouchpadGestureResult>[
        ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.scroll,
          cancelled: true,
        ),
      ],
      _ => const <TouchpadGestureResult>[],
    };
    _finishOrSuppress();
    return results;
  }

  /// Cancels a gesture because the surface/session/controller is going away.
  List<TouchpadGestureResult> forceCancel() {
    final id = _sessionId;
    final phase = _phase;
    final results = id == null
        ? const <TouchpadGestureResult>[]
        : switch (phase) {
            TouchpadPhase.dragging => <TouchpadGestureResult>[
              ContinuousGestureEndResult(
                id,
                ContinuousGestureKind.drag,
                cancelled: true,
              ),
            ],
            TouchpadPhase.scrolling => <TouchpadGestureResult>[
              ContinuousGestureEndResult(
                id,
                ContinuousGestureKind.scroll,
                cancelled: true,
              ),
            ],
            _ => const <TouchpadGestureResult>[],
          };
    _reset();
    return results;
  }

  List<TouchpadGestureResult> _suppress({required bool cancelActive}) {
    final id = _sessionId;
    final phase = _phase;
    _phase = TouchpadPhase.suppressed;
    _dragArmedOrigin = null;
    _twoFingerOrigin = null;
    _twoFingerLast = null;
    if (!cancelActive || id == null) return const [];
    if (phase == TouchpadPhase.dragging) {
      return [
        ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.drag,
          cancelled: true,
        ),
      ];
    }
    if (phase == TouchpadPhase.scrolling) {
      return [
        ContinuousGestureEndResult(
          id,
          ContinuousGestureKind.scroll,
          cancelled: true,
        ),
      ];
    }
    return const [];
  }

  List<TouchpadGestureResult> _nonZeroCursorResult(int id, Offset delta) {
    if (delta == Offset.zero) return const [];
    return [CursorMoveResult(id, delta.dx, delta.dy)];
  }

  List<TouchpadGestureResult> _nonZeroContinuousResult(
    int id,
    ContinuousGestureKind kind,
    Offset delta,
  ) {
    if (delta == Offset.zero) return const [];
    return [ContinuousGestureMoveResult(id, kind, delta.dx, delta.dy)];
  }

  Offset? _centroid() {
    if (_pointers.length != 2) return null;
    final values = _pointers.values.toList(growable: false);
    return Offset(
      (values[0].lastPosition.dx + values[1].lastPosition.dx) / 2,
      (values[0].lastPosition.dy + values[1].lastPosition.dy) / 2,
    );
  }

  void _finishOrSuppress() {
    if (_pointers.isEmpty) {
      _reset();
    } else {
      _phase = TouchpadPhase.suppressed;
      _dragArmedOrigin = null;
      _twoFingerOrigin = null;
      _twoFingerLast = null;
    }
  }

  void _finishIfEmpty() {
    if (_pointers.isEmpty) _reset();
  }

  void _reset() {
    _pointers.clear();
    _phase = TouchpadPhase.idle;
    _sessionId = null;
    _sessionStartTime = Duration.zero;
    _dragArmedOrigin = null;
    _twoFingerOrigin = null;
    _twoFingerLast = null;
  }
}
