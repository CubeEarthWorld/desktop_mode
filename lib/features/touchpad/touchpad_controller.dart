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
  });

  final Map<int, Offset> activeTouches;
  final List<FadingGlow> fadingGlows;
  final bool locked;
  final double unlockHoldProgress;

  TouchpadState copyWith({
    Map<int, Offset>? activeTouches,
    List<FadingGlow>? fadingGlows,
    bool? locked,
    double? unlockHoldProgress,
  }) => TouchpadState(
    activeTouches: activeTouches ?? this.activeTouches,
    fadingGlows: fadingGlows ?? this.fadingGlows,
    locked: locked ?? this.locked,
    unlockHoldProgress: unlockHoldProgress ?? this.unlockHoldProgress,
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
  double _pendingSwipeDx = 0;
  double _pendingSwipeDy = 0;
  bool _frameScheduled = false;
  int _nextGlowId = 0;

  Timer? _idleLockTimer;
  Timer? _unlockHoldTimer;
  int? _unlockHoldPointerId;

  /// 静止長押しでドラッグ武装するための検知タイマー。認識器は自前の時計を
  /// 持たない純 Dart クラスのため、実時間の計測はここで行う(§ タッチ操作)。
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
      _beginUnlockHold(id);
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
    if (state.locked) return;
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
    // システムが途中でジェスチャーを打ち切った場合でも、ドラッグ/2本指スワイプ中で
    // あれば必ずネイティブ側へ終了を伝える(結果を握り潰すと native の直列化ガードが
    // 解放されず、以後のあらゆる操作が busy になる不具合の原因になる)。
    _applyResults(_recognizer.onPointerCancel(id));
  }

  /// 指を動かさずに [AppSettings.longPressDurationMs] だけ静止し続けたら
  /// ドラッグ武装状態にする(認識器自体は時計を持たないため、実時間の計測はここで行う)。
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
          _fireAndForget('pointerDown', api.pointerDown);
        case DragMoveResult(:final dx, :final dy):
          _pendingDragDx += dx;
          _pendingDragDy += dy;
          _scheduleFlush();
        case DragEndResult():
          _fireAndForget('pointerUp', api.pointerUp);
        case LeftClickResult():
          _fireAndForget('leftClick', api.leftClick);
        case LongPressResult():
          _fireAndForget('longPress', api.longPress);
        case TwoFingerSwipeStartResult():
          _fireAndForget('twoFingerMoveStart', api.twoFingerMoveStart);
        case TwoFingerSwipeMoveResult(:final dx, :final dy):
          _pendingSwipeDx += dx;
          _pendingSwipeDy += dy;
          _scheduleFlush();
        case TwoFingerSwipeEndResult():
          _fireAndForget('twoFingerMoveEnd', api.twoFingerMoveEnd);
      }
    }
  }

  void _scheduleFlush() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      final dx = _pendingDx;
      final dy = _pendingDy;
      final dragDx = _pendingDragDx;
      final dragDy = _pendingDragDy;
      final swipeDx = _pendingSwipeDx;
      final swipeDy = _pendingSwipeDy;
      _pendingDx = 0;
      _pendingDy = 0;
      _pendingDragDx = 0;
      _pendingDragDy = 0;
      _pendingSwipeDx = 0;
      _pendingSwipeDy = 0;

      final api = ref.read(desktopModeApiProvider);
      if (dx != 0 || dy != 0) {
        _fireAndForget('moveCursor', () => api.moveCursor(dx, dy));
      }
      if (dragDx != 0 || dragDy != 0) {
        _fireAndForget('pointerMove', () => api.pointerMove(dragDx, dragDy));
      }
      if (swipeDx != 0 || swipeDy != 0) {
        _fireAndForget('twoFingerMoveBy', () => api.twoFingerMoveBy(swipeDx, swipeDy));
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
    state = state.copyWith(
      locked: true,
      activeTouches: const {},
      fadingGlows: const [],
      unlockHoldProgress: 0,
    );
  }

  void _beginUnlockHold(int pointerId) {
    if (_unlockHoldPointerId != null) return;
    _unlockHoldPointerId = pointerId;
    var elapsedMs = 0;
    _unlockHoldTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      elapsedMs += 40;
      final progress = (elapsedMs / _unlockHoldDuration.inMilliseconds).clamp(0.0, 1.0);
      state = state.copyWith(unlockHoldProgress: progress);
      if (progress >= 1.0) {
        timer.cancel();
        _unlockHoldTimer = null;
        _unlockHoldPointerId = null;
        state = state.copyWith(locked: false, unlockHoldProgress: 0);
        _armIdleLockTimer();
      }
    });
  }

  void _cancelUnlockHold(int pointerId) {
    if (_unlockHoldPointerId != pointerId) return;
    _unlockHoldTimer?.cancel();
    _unlockHoldTimer = null;
    _unlockHoldPointerId = null;
    state = state.copyWith(unlockHoldProgress: 0);
  }
}
