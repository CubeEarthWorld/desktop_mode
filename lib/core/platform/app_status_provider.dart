import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/desktop_mode_event.dart';
import '../../models/display_info.dart';
import '../../models/session_state.dart';
import 'desktop_mode_channel.dart';

/// アプリ全体で共有する状態(Accessibility/外部ディスプレイ/セッション)。
class AppStatus {
  const AppStatus({
    this.accessibilityEnabled = false,
    this.displays = const [],
    this.sessionState = SessionState.idleState,
  });

  final bool accessibilityEnabled;
  final List<DisplayInfo> displays;
  final SessionState sessionState;

  List<DisplayInfo> get externalDisplays => displays.where((d) => !d.isDefault).toList();
  bool get hasExternalDisplay => externalDisplays.isNotEmpty;
  bool get canOpenTouchpad => accessibilityEnabled && hasExternalDisplay;

  AppStatus copyWith({
    bool? accessibilityEnabled,
    List<DisplayInfo>? displays,
    SessionState? sessionState,
  }) => AppStatus(
    accessibilityEnabled: accessibilityEnabled ?? this.accessibilityEnabled,
    displays: displays ?? this.displays,
    sessionState: sessionState ?? this.sessionState,
  );
}

final appStatusProvider = NotifierProvider<AppStatusController, AppStatus>(
  AppStatusController.new,
);

/// Accessibility/外部ディスプレイ/セッション状態の唯一の情報源。
/// native からの push イベント(仕様 R10)を購読して更新し、ポーリングは行わない。
class AppStatusController extends Notifier<AppStatus> with WidgetsBindingObserver {
  @override
  AppStatus build() {
    ref.listen(desktopModeEventsProvider, (previous, next) {
      next.whenData(_handleEvent);
    });
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    unawaited(_refresh());
    return const AppStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // バックグラウンドにいた間にセッションが停止した(displayRemoved等)場合、
      // push イベントを受け取れていない可能性がある。フォアグラウンド復帰時に
      // 最新状態を再取得し、トップ画面への遷移等を確実に行う。
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final api = ref.read(desktopModeApiProvider);
    final accessibilityEnabled = await api.isAccessibilityEnabled();
    final displays = await api.getDisplays();
    final sessionState = await api.getSessionState();
    state = state.copyWith(
      accessibilityEnabled: accessibilityEnabled,
      displays: displays,
      sessionState: sessionState,
    );
  }

  Future<void> _refreshDisplaysOnly() async {
    final displays = await ref.read(desktopModeApiProvider).getDisplays();
    state = state.copyWith(displays: displays);
  }

  void _handleEvent(DesktopModeEvent event) {
    switch (event) {
      case DisplayAddedEvent():
      case DisplayRemovedEvent():
      case DisplayChangedEvent():
        unawaited(_refreshDisplaysOnly());
      case AccessibilityStateChangedEvent(:final enabled):
        state = state.copyWith(accessibilityEnabled: enabled);
      case SessionStartedEvent(:final sessionState):
        state = state.copyWith(sessionState: sessionState);
      case SessionStoppedEvent():
        state = state.copyWith(sessionState: SessionState.idleState);
      case NativeErrorEvent():
        break;
    }
  }
}
