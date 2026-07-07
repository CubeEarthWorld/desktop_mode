import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/desktop_mode_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import 'touchpad_gesture_recognizer.dart';

/// ジェスチャ注入の失敗(busy 等)は native 側の直列化ガードによる正常な却下であり、
/// 未捕捉例外としてログを汚す必要はない。ここで一括して捕捉し、診断用に一行だけ残す。
void _fireAndForget(String label, Future<void> Function() action) {
  unawaited(
    action().catchError((Object error) {
      if (error is PlatformException) {
        debugPrint('[Touchpad] $label failed: ${error.code} ${error.message ?? ''}');
      } else {
        debugPrint('[Touchpad] $label failed: $error');
      }
    }),
  );
}

const _idleLockDelay = Duration(seconds: 30);
const _unlockHoldDuration = Duration(milliseconds: 2000);
const _unlockHoldSlop = 12.0;
const _glowFadeDuration = Duration(milliseconds: 300);

/// フェードアウト中のタッチ発光。`pointerId` ではなく単調増加 id で管理し、
/// 指を離した直後に同じ pointerId が再利用されても取り違えない。
class FadingGlow {
  const FadingGlow(this.id, this.position);
  final int id;
  final Offset position;
}

class TouchpadState {
  const TouchpadState({
    this.activeTouches = const {},
    this.fadingGlows = const [],
    this.locked = false,
    this.unlockHoldProgress = 0,
    this.currentPhase = 'idle',
    this.lastGestureResult = '-',
  });

  final Map<int, Offset> activeTouches;
  final List<FadingGlow> fadingGlows;
  final bool locked;
  final double unlockHoldProgress;
  final String currentPhase;
  final String lastGestureResult;

  TouchpadState copyWith({
    Map<int, Offset>? activeTouches,
    List<FadingGlow>? fadingGlows,
    bool? locked,
    double? unlockHoldProgress,
    String? currentPhase,
    String? lastGestureResult,
  }) => TouchpadState(
    activeTouches: activeTouches ?? this.activeTouches,
    fadingGlows: fadingGlows ?? this.fadingGlows,
    locked: locked ?? this.locked,
    unlockHoldProgress: unlockHoldProgress ?? this.unlockHoldProgress,
    currentPhase: currentPhase ?? this.currentPhase,
    lastGestureResult: lastGestureResult ?? this.lastGestureResult,
  );
}

final touchpadControllerProvider = NotifierProvider.autoDispose<TouchpadController, TouchpadState>(
  TouchpadController.new,
);

/// タッチパッド画面の実行時状態(ジェスチャ・タッチ発光・誤操作ロック)を束ねる。
/// 認識は [TouchpadGestureRecognizer] に、native 呼び出しは [DesktopModeApi] に委譲する(SRP)。
class TouchpadController extends Notifier<TouchpadState> {
  TouchpadGestureRecognizer _recognizer = TouchpadGestureRecognizer();
  AppSettings _settings = const AppSettings();

  double _pendingDx = 0;
  double _pendingDy = 0;
  double _pendingDragDx = 0;
  double _pendingDragDy = 0;
  double _pendingScrollDx = 0;
  double _pendingScrollDy = 0;
  bool _frameScheduled = false;
  int _nextGlowId = 0;

  // ドラッグ/2本指スクロールの開始を、最初の移動とまとめて dispatch するための保留状態。
  // 開始だけを短いタップとして送出すると外部ディスプレイ側でクリックと誤認識されるため、
  // 最初の移動が来るまで待機する。
  bool _dragStartPending = false;
  bool _scrollStartPending = false;

  Timer? _idleLockTimer;
  Timer? _unlockHoldTimer;
  int? _unlockHoldPointerId;
  Offset? _unlockHoldStartPosition;

  /// 静止長押しでドラッグ/長押し判定の閾値を超えるための検知タイマー。
  /// 認識器は自前の時計を持たない純 Dart クラスのため、実時間の計測はここで行う。
  Timer? _longPressTimer;

  @override
  TouchpadState build() {
    _settings = ref.read(settingsProvider).value ?? const AppSettings();
    ref.listen(settingsProvider, (previous, next) {
      final settings = next.value;
      if (settings != null) _settings = settings;
    });
    _armIdleLockTimer();
    ref.onDispose(() {
      _idleLockTimer?.cancel();
      _unlockHoldTimer?.cancel();
      _longPressTimer?.cancel();
    });
    return const TouchpadState();
  }

  void handlePointerDown(int id, Offset position, Duration timestamp) {
    if (state.locked) {
      _beginUnlockHold(id, position);
      return;
    }
    _armIdleLockTimer();
    state = state.copyWith(activeTouches: {...state.activeTouches, id: position});
    if (_settings.showTouchGlow) {
      _fireAndForget(
        'showTouchEffectAtCursor',
        () => ref.read(desktopModeApiProvider).showTouchEffectAtCursor(),
      );
    }
    _applyResults(_recognizer.onPointerDown(id, position, timestamp));
    _armLongPressTimer(id);
  }

  void handlePointerMove(int id, Offset position, Duration timestamp) {
    if (state.locked) {
      _checkUnlockHoldMove(id, position);
      return;
    }
    _armIdleLockTimer();
    state = state.copyWith(activeTouches: {...state.activeTouches, id: position});
    _applyResults(_recognizer.onPointerMove(id, position, timestamp));
  }

  void handlePointerUp(int id, Duration timestamp) {
    if (state.locked) {
      _cancelUnlockHold(id);
      return;
    }
    _armIdleLockTimer();
    _longPressTimer?.cancel();
    final touches = Map<int, Offset>.from(state.activeTouches);
    final lastPosition = touches.remove(id);
    var glows = state.fadingGlows;
    if (_settings.showTouchGlow && lastPosition != null) {
      final glowId = _nextGlowId++;
      glows = [...glows, FadingGlow(glowId, lastPosition)];
      Timer(_glowFadeDuration, () => _removeGlow(glowId));
    }
    state = state.copyWith(activeTouches: touches, fadingGlows: glows);
    _applyResults(_recognizer.onPointerUp(id, timestamp));
  }

  void handlePointerCancel(int id) {
    if (state.locked) {
      _cancelUnlockHold(id);
      return;
    }
    _longPressTimer?.cancel();
    final touches = Map<int, Offset>.from(state.activeTouches)..remove(id);
    state = state.copyWith(activeTouches: touches);
    // システムが途中でジェスチャーを打ち切った場合でも、ドラッグ/2本指スクロール中で
    // あれば必ずネイティブ側へ終了を伝える(結果を握り潰すと native の直列化ガードが
    // 解放されず、以後のあらゆる操作が busy になる不具合の原因になる)。
    _applyResults(_recognizer.onPointerCancel(id));
  }

  /// 指を動かさずに [AppSettings.longPressDurationMs] だけ静止し続けたら
  /// 長押し/ドラッグ判定の閾値を超える(認識器自体は時計を持たないため、実時間の計測はここで行う)。
  void _armLongPressTimer(int pointerId) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(Duration(milliseconds: _settings.longPressDurationMs), () {
      _applyResults(_recognizer.onLongPressTimeout(pointerId));
    });
  }

  void _removeGlow(int glowId) {
    state = state.copyWith(fadingGlows: state.fadingGlows.where((g) => g.id != glowId).toList());
  }

  void _applyResults(List<TouchpadGestureResult> results) {
    final api = ref.read(desktopModeApiProvider);
    for (final result in results) {
      switch (result) {
        case CursorMoveResult(:final dx, :final dy):
          _pendingDx += dx;
          _pendingDy += dy;
          _scheduleFlush();
        case DragStartResult():
          // 最初の移動とまとめて送出するため、開始だけは保留する。
          _dragStartPending = true;
        case DragMoveResult(:final dx, :final dy):
          _pendingDragDx += dx;
          _pendingDragDy += dy;
          if (_dragStartPending) {
            _dragStartPending = false;
            _fireAndForget('pointerDown', api.pointerDown);
          }
          _scheduleFlush();
        case DragEndResult():
          _dragStartPending = false;
          _fireAndForget('pointerUp', api.pointerUp);
        case LeftClickResult():
          _fireAndForget('leftClick', api.leftClick);
        case LongPressResult():
          _fireAndForget('longPress', api.longPress);
        case TwoFingerScrollStartResult():
          // 最初の移動とまとめて送出するため、開始だけは保留する。
          _scrollStartPending = true;
        case TwoFingerScrollMoveResult(:final dx, :final dy):
          _pendingScrollDx += dx;
          _pendingScrollDy += dy;
          if (_scrollStartPending) {
            _scrollStartPending = false;
            _fireAndForget('twoFingerScrollStart', api.twoFingerScrollStart);
          }
          _scheduleFlush();
        case TwoFingerScrollEndResult():
          _scrollStartPending = false;
          _fireAndForget('twoFingerScrollEnd', api.twoFingerScrollEnd);
        case TwoFingerSwipeResult(:final dx, :final dy):
          _scrollStartPending = false;
          _fireAndForget('twoFingerSwipe', () => api.twoFingerSwipe(dx, dy));
      }
      _updateDiagnosticState(result);
    }
  }

  void _updateDiagnosticState(TouchpadGestureResult result) {
    state = state.copyWith(
      currentPhase: _recognizer.currentPhaseName,
      lastGestureResult: _resultLabel(result),
    );
  }

  String _resultLabel(TouchpadGestureResult result) => switch (result) {
    CursorMoveResult() => 'move',
    LeftClickResult() => 'tap',
    LongPressResult() => 'longPress',
    DragStartResult() => 'dragStart',
    DragMoveResult() => 'dragMove',
    DragEndResult() => 'dragEnd',
    TwoFingerScrollStartResult() => 'scrollStart',
    TwoFingerScrollMoveResult() => 'scrollMove',
    TwoFingerScrollEndResult() => 'scrollEnd',
    TwoFingerSwipeResult() => 'swipe',
  };

  void _scheduleFlush() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      final dx = _pendingDx;
      final dy = _pendingDy;
      final dragDx = _pendingDragDx;
      final dragDy = _pendingDragDy;
      final scrollDx = _pendingScrollDx;
      final scrollDy = _pendingScrollDy;
      _pendingDx = 0;
      _pendingDy = 0;
      _pendingDragDx = 0;
      _pendingDragDy = 0;
      _pendingScrollDx = 0;
      _pendingScrollDy = 0;

      final api = ref.read(desktopModeApiProvider);
      if (dx != 0 || dy != 0) {
        _fireAndForget('moveCursor', () => api.moveCursor(dx, dy));
      }
      if (dragDx != 0 || dragDy != 0) {
        _fireAndForget('pointerMove', () => api.pointerMove(dragDx, dragDy));
      }
      if (scrollDx != 0 || scrollDy != 0) {
        _fireAndForget('twoFingerScrollBy', () => api.twoFingerScrollBy(scrollDx, scrollDy));
      }
    });
  }

  // ---- 誤操作防止(タッチロック、設定 ON のときのみ、仕様 §8.7) ----

  void _armIdleLockTimer() {
    _idleLockTimer?.cancel();
    if (!_settings.touchLockEnabled) return;
    _idleLockTimer = Timer(_idleLockDelay, _lock);
  }

  void _lock() {
    _recognizer = TouchpadGestureRecognizer();
    _dragStartPending = false;
    _scrollStartPending = false;
    state = state.copyWith(
      locked: true,
      activeTouches: const {},
      fadingGlows: const [],
      unlockHoldProgress: 0,
      currentPhase: 'idle',
      lastGestureResult: '-',
    );
  }

  /// ユーザーが手動で即座にロックする。設定でタッチロックが有効な場合のみ
  /// UI から呼ばれる。
  void lockNow() {
    _idleLockTimer?.cancel();
    _lock();
  }

  void _beginUnlockHold(int pointerId, Offset position) {
    if (_unlockHoldPointerId != null) return;
    _unlockHoldPointerId = pointerId;
    _unlockHoldStartPosition = position;
    var elapsedMs = 0;
    _unlockHoldTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      elapsedMs += 40;
      final progress = (elapsedMs / _unlockHoldDuration.inMilliseconds).clamp(0.0, 1.0);
      state = state.copyWith(unlockHoldProgress: progress);
      if (progress >= 1.0) {
        timer.cancel();
        _unlockHoldTimer = null;
        _unlockHoldPointerId = null;
        _unlockHoldStartPosition = null;
        state = state.copyWith(locked: false, unlockHoldProgress: 0);
        _armIdleLockTimer();
      }
    });
  }

  void _checkUnlockHoldMove(int pointerId, Offset position) {
    if (_unlockHoldPointerId != pointerId) return;
    final start = _unlockHoldStartPosition;
    if (start == null) return;
    if ((position - start).distance > _unlockHoldSlop) {
      _cancelUnlockHold(pointerId);
    }
  }

  void _cancelUnlockHold(int pointerId) {
    if (_unlockHoldPointerId != pointerId) return;
    _unlockHoldTimer?.cancel();
    _unlockHoldTimer = null;
    _unlockHoldPointerId = null;
    _unlockHoldStartPosition = null;
    state = state.copyWith(unlockHoldProgress: 0);
  }
}
