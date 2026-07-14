import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/external_touchpad_api.dart';
import '../../core/platform/external_touchpad_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_dimens.dart';
import 'touchpad_gesture_recognizer.dart';

const _unlockHoldDuration = Duration(milliseconds: AppDimens.touchLockHoldMs);
const _glowFadeDuration = Duration(milliseconds: AppDimens.touchGlowFadeOutMs);
const _platformCommandTimeout = Duration(seconds: 4);

class FadingGlow {
  const FadingGlow(this.id, this.position);

  final int id;
  final Offset position;
}

class TouchpadState {
  const TouchpadState({
    this.fadingGlows = const [],
    this.locked = false,
    this.unlockHoldProgress = 0,
    this.unlockAttemptActive = false,
    this.phase = TouchpadPhase.idle,
    this.gestureSessionId,
  });

  final List<FadingGlow> fadingGlows;
  final bool locked;
  final double unlockHoldProgress;
  // ロック解除ホールド中(指を置いてから離す/解除完了するまで)は true。
  // この間は輝度最小化を解除し、進捗リングと錠アイコンをユーザーが確認できるようにする。
  final bool unlockAttemptActive;
  final TouchpadPhase phase;
  final int? gestureSessionId;

  TouchpadState copyWith({
    List<FadingGlow>? fadingGlows,
    bool? locked,
    double? unlockHoldProgress,
    bool? unlockAttemptActive,
    TouchpadPhase? phase,
    int? gestureSessionId,
    bool clearGestureSessionId = false,
  }) => TouchpadState(
    fadingGlows: fadingGlows ?? this.fadingGlows,
    locked: locked ?? this.locked,
    unlockHoldProgress: unlockHoldProgress ?? this.unlockHoldProgress,
    unlockAttemptActive: unlockAttemptActive ?? this.unlockAttemptActive,
    phase: phase ?? this.phase,
    gestureSessionId: clearGestureSessionId
        ? null
        : (gestureSessionId ?? this.gestureSessionId),
  );
}

final touchpadControllerProvider =
    NotifierProvider.autoDispose<TouchpadController, TouchpadState>(
      TouchpadController.new,
    );

class TouchpadController extends Notifier<TouchpadState> {
  final TouchpadGestureRecognizer _recognizer = TouchpadGestureRecognizer();
  late ExternalTouchpadApi _api;
  AppSettings _settings = const AppSettings();

  double _pendingCursorDx = 0;
  double _pendingCursorDy = 0;
  int? _pendingContinuousId;
  ContinuousGestureKind? _pendingContinuousKind;
  double _pendingContinuousDx = 0;
  double _pendingContinuousDy = 0;
  int? _activeContinuousId;
  ContinuousGestureKind? _activeContinuousKind;
  bool _frameScheduled = false;

  Future<void> _commandTail = Future<void>.value();
  bool _disposed = false;

  int _nextGlowId = 0;
  final Map<int, Timer> _glowTimers = {};
  final Map<int, Offset> _touchPositions = {};
  Timer? _idleLockTimer;
  bool _idleLockPaused = false;
  Timer? _unlockHoldTimer;
  Timer? _longPressTimer;
  int? _unlockHoldPointerId;
  Offset? _unlockHoldOrigin;
  String? _publishedPhase;
  int? _publishedSessionId;

  @visibleForTesting
  Future<void> get debugPendingCommands => _commandTail;

  @override
  TouchpadState build() {
    _api = ref.read(externalTouchpadApiProvider);
    _settings = ref.read(settingsProvider).value ?? const AppSettings();
    ref.listen(settingsProvider, (previous, next) {
      final settings = next.value;
      if (settings == null) return;
      final shouldRearmLock =
          settings.touchLockEnabled != _settings.touchLockEnabled ||
          settings.touchLockIdleTimeoutSeconds !=
              _settings.touchLockIdleTimeoutSeconds;
      _settings = settings;
      if (shouldRearmLock && !state.locked) _armIdleLockTimer();
    });
    _armIdleLockTimer();
    ref.onDispose(_dispose);
    return const TouchpadState();
  }

  void handlePointerDown(int id, Offset position, Duration timestamp) {
    if (state.locked) {
      _beginUnlockHold(id, position);
      return;
    }
    _armIdleLockTimer();
    if (_touchPositions.isEmpty) {
      unawaited(_api.dismissSoftKeyboard().catchError((Object _) {}));
    }
    _touchPositions[id] = position;
    _applyResults(_recognizer.onPointerDown(id, position, timestamp));

    if (_recognizer.phase == TouchpadPhase.oneFingerPending) {
      _armLongPressTimer(id, _recognizer.sessionId!);
    } else {
      _longPressTimer?.cancel();
    }
    if (_recognizer.phase == TouchpadPhase.twoFingerPending) {
      _discardPendingCursorMove();
    }
    _syncRecognizerState();
  }

  void handlePointerMove(int id, Offset position, Duration timestamp) {
    if (state.locked) {
      // 解除ホールド中に指が動いたら、指を離したときと同じく解除失敗にする。
      final origin = _unlockHoldOrigin;
      if (id == _unlockHoldPointerId &&
          origin != null &&
          (position - origin).distance > AppDimens.touchLockUnlockMoveSlop) {
        _cancelUnlockHold(id);
      }
      return;
    }
    _armIdleLockTimer();
    _touchPositions[id] = position;
    _applyResults(_recognizer.onPointerMove(id, position, timestamp));
    if (_recognizer.phase != TouchpadPhase.oneFingerPending) {
      _longPressTimer?.cancel();
    }
    _syncRecognizerState();
  }

  void handlePointerUp(int id, Offset position, Duration timestamp) {
    if (state.locked) {
      _cancelUnlockHold(id);
      return;
    }
    _armIdleLockTimer();
    _longPressTimer?.cancel();
    _touchPositions.remove(id);
    _applyResults(
      _recognizer.onPointerUp(id, position, timestamp),
      feedbackPosition: position,
    );
    _syncRecognizerState();
  }

  void handlePointerCancel(int id) {
    if (state.locked) {
      _cancelUnlockHold(id);
      return;
    }
    _longPressTimer?.cancel();
    _touchPositions.remove(id);
    _applyResults(_recognizer.onPointerCancel(id));
    _syncRecognizerState();
  }

  void _armLongPressTimer(int pointerId, int sessionId) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(
      Duration(milliseconds: _settings.longPressDurationMs),
      () {
        if (_disposed) return;
        _applyResults(_recognizer.onLongPressTimeout(pointerId, sessionId));
        _syncRecognizerState();
      },
    );
  }

  void _applyResults(
    List<TouchpadGestureResult> results, {
    Offset? feedbackPosition,
  }) {
    for (final result in results) {
      switch (result) {
        case CursorMoveResult(:final dx, :final dy):
          _pendingCursorDx += dx;
          _pendingCursorDy += dy;
          _scheduleFlush();

        case LeftClickResult():
          if (feedbackPosition != null && _settings.showTouchGlow) {
            _addCommittedGlow(feedbackPosition);
          }
          _enqueueCommand('click', () async {
            await _api.commitPointerAction(
              PointerActionType.click,
              showFeedback: _settings.showTouchGlow,
            );
          });

        case LongPressResult():
          if (feedbackPosition != null && _settings.showTouchGlow) {
            _addCommittedGlow(feedbackPosition);
          }
          _enqueueCommand('longPress', () async {
            await _api.commitPointerAction(
              PointerActionType.longPress,
              showFeedback: _settings.showTouchGlow,
            );
          });

        case ContinuousGestureStartResult(:final sessionId, :final kind):
          _activeContinuousId = sessionId;
          _activeContinuousKind = kind;
          _enqueueCommand('beginContinuousGesture', () async {
            await _api.beginContinuousGesture(sessionId, _toRemoteKind(kind));
          });

        case ContinuousGestureMoveResult(
          :final sessionId,
          :final kind,
          :final dx,
          :final dy,
        ):
          if (_activeContinuousId != sessionId ||
              _activeContinuousKind != kind) {
            continue;
          }
          if (_pendingContinuousId != null &&
              (_pendingContinuousId != sessionId ||
                  _pendingContinuousKind != kind)) {
            _flushContinuousNow(_pendingContinuousId!);
          }
          final multiplier = kind == ContinuousGestureKind.drag
              ? AppSettings.dragSensitivityMultiplier(_settings.dragSensitivity)
              : 1.0;
          _pendingContinuousId = sessionId;
          _pendingContinuousKind = kind;
          _pendingContinuousDx += dx * multiplier;
          _pendingContinuousDy += dy * multiplier;
          _scheduleFlush();

        case ContinuousGestureEndResult(
          :final sessionId,
          :final kind,
          :final cancelled,
        ):
          if (_activeContinuousId != sessionId ||
              _activeContinuousKind != kind) {
            continue;
          }
          _flushContinuousNow(sessionId);
          _activeContinuousId = null;
          _activeContinuousKind = null;
          _enqueueCommand('endContinuousGesture', () async {
            await _api.endContinuousGesture(sessionId, cancelled: cancelled);
          });
      }
    }
  }

  RemoteGestureKind _toRemoteKind(ContinuousGestureKind kind) => switch (kind) {
    ContinuousGestureKind.drag => RemoteGestureKind.drag,
    ContinuousGestureKind.scroll => RemoteGestureKind.scroll,
  };

  void _scheduleFlush() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (_disposed) return;
      _flushCursorNow();
      final id = _pendingContinuousId;
      if (id != null) _flushContinuousNow(id);
    });
  }

  void _flushCursorNow() {
    final dx = _pendingCursorDx;
    final dy = _pendingCursorDy;
    _pendingCursorDx = 0;
    _pendingCursorDy = 0;
    if (dx == 0 && dy == 0) return;
    _enqueueCommand('moveCursor', () => _api.moveCursor(dx, dy));
  }

  void _discardPendingCursorMove() {
    _pendingCursorDx = 0;
    _pendingCursorDy = 0;
  }

  void _flushContinuousNow(int sessionId) {
    if (_pendingContinuousId != sessionId) return;
    final dx = _pendingContinuousDx;
    final dy = _pendingContinuousDy;
    _pendingContinuousId = null;
    _pendingContinuousKind = null;
    _pendingContinuousDx = 0;
    _pendingContinuousDy = 0;
    if (dx == 0 && dy == 0) return;
    _enqueueCommand('updateContinuousGesture', () async {
      await _api.updateContinuousGesture(sessionId, dx, dy);
    });
  }

  void _enqueueCommand(String label, Future<void> Function() action) {
    _commandTail = _commandTail.then((_) async {
      try {
        // A missing OEM Accessibility callback must not permanently block the
        // serialized input stream. Native has its own shorter watchdog; this
        // is the final safety net for a MethodChannel reply that never arrives.
        await action().timeout(_platformCommandTimeout);
      } on TimeoutException {
        debugPrint('[Touchpad] $label timed out; continuing input queue');
      } catch (error) {
        if (error is PlatformException) {
          debugPrint(
            '[Touchpad] $label failed: ${error.code} ${error.message ?? ''}',
          );
        } else {
          debugPrint('[Touchpad] $label failed: $error');
        }
      }
    });
  }

  void _syncRecognizerState() {
    final phase = _recognizer.phase;
    final sessionId = _recognizer.sessionId;
    state = state.copyWith(
      phase: phase,
      gestureSessionId: sessionId,
      clearGestureSessionId: sessionId == null,
    );
    if (_publishedPhase == phase.name && _publishedSessionId == sessionId) {
      return;
    }
    _publishedPhase = phase.name;
    _publishedSessionId = sessionId;
    unawaited(
      _api
          .updateInputDiagnostics(phase: phase.name, sessionId: sessionId)
          .catchError((Object error) {
            debugPrint('[Touchpad] input diagnostics failed: $error');
          }),
    );
  }

  void _addCommittedGlow(Offset position) {
    final id = _nextGlowId++;
    state = state.copyWith(
      fadingGlows: [...state.fadingGlows, FadingGlow(id, position)],
    );
    _glowTimers[id] = Timer(_glowFadeDuration, () {
      _glowTimers.remove(id);
      if (_disposed) return;
      state = state.copyWith(
        fadingGlows: state.fadingGlows.where((glow) => glow.id != id).toList(),
      );
    });
  }

  void _armIdleLockTimer() {
    _idleLockTimer?.cancel();
    if (_idleLockPaused || !_settings.touchLockEnabled) return;
    _idleLockTimer = Timer(
      Duration(seconds: _settings.touchLockIdleTimeoutSeconds),
      _lock,
    );
  }

  /// タッチパッド画面が設定画面などに覆われている間、ロックまでのカウントダウンを
  /// 止める(タッチできない画面を見ている間に勝手にロックされるのを防ぐ)。覆われている
  /// 間に設定を変更してもカウントダウンが再開しないよう、`_armIdleLockTimer` 自体を
  /// 抑止するフラグとして持つ。
  void pauseIdleLock() {
    _idleLockPaused = true;
    _idleLockTimer?.cancel();
    _idleLockTimer = null;
  }

  /// タッチパッド画面に戻ったとき、カウントダウンを最初からやり直す。
  void resumeIdleLock() {
    _idleLockPaused = false;
    if (state.locked) return;
    _armIdleLockTimer();
  }

  /// タッチロック設定が ON のとき、ユーザーが明示的に今すぐロックするための入口。
  void lockNow() {
    if (!_settings.touchLockEnabled || state.locked) return;
    _idleLockTimer?.cancel();
    _lock();
  }

  void _lock() {
    _longPressTimer?.cancel();
    _applyResults(_recognizer.forceCancel());
    _discardPendingCursorMove();
    _touchPositions.clear();
    state = state.copyWith(
      locked: true,
      fadingGlows: const [],
      unlockHoldProgress: 0,
      unlockAttemptActive: false,
      phase: TouchpadPhase.idle,
      clearGestureSessionId: true,
    );
    _syncRecognizerState();
  }

  void _beginUnlockHold(int pointerId, Offset position) {
    if (_unlockHoldPointerId != null) return;
    _unlockHoldPointerId = pointerId;
    _unlockHoldOrigin = position;
    state = state.copyWith(unlockAttemptActive: true);
    var elapsedMs = 0;
    _unlockHoldTimer = Timer.periodic(const Duration(milliseconds: 40), (
      timer,
    ) {
      elapsedMs += 40;
      final progress = (elapsedMs / _unlockHoldDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      );
      state = state.copyWith(unlockHoldProgress: progress);
      if (progress >= 1.0) {
        timer.cancel();
        _unlockHoldTimer = null;
        _unlockHoldPointerId = null;
        _unlockHoldOrigin = null;
        state = state.copyWith(
          locked: false,
          unlockHoldProgress: 0,
          unlockAttemptActive: false,
        );
        _armIdleLockTimer();
      }
    });
  }

  void _cancelUnlockHold(int pointerId) {
    if (_unlockHoldPointerId != pointerId) return;
    _unlockHoldTimer?.cancel();
    _unlockHoldTimer = null;
    _unlockHoldPointerId = null;
    _unlockHoldOrigin = null;
    state = state.copyWith(unlockHoldProgress: 0, unlockAttemptActive: false);
  }

  void _dispose() {
    _longPressTimer?.cancel();
    _idleLockTimer?.cancel();
    _unlockHoldTimer?.cancel();
    for (final timer in _glowTimers.values) {
      timer.cancel();
    }
    _glowTimers.clear();
    _touchPositions.clear();

    final results = _recognizer.forceCancel();
    for (final result in results.whereType<ContinuousGestureEndResult>()) {
      _flushContinuousNow(result.sessionId);
      _enqueueCommand('disposeGesture', () async {
        await _api.endContinuousGesture(result.sessionId, cancelled: true);
      });
    }
    _disposed = true;
  }
}
