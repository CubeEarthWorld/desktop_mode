import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/platform/app_status_provider.dart';
import '../../core/platform/external_touchpad_api.dart';
import '../../core/platform/external_touchpad_channel.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../l10n/l10n.dart';
import 'touchpad_controller.dart';
import 'widgets/app_list_sheet.dart';
import 'widgets/lock_overlay.dart';
import 'widgets/system_nav_bar.dart';
import 'widgets/touch_surface.dart';

/// 本体画面のタッチパッド UI。セッションのライフサイクル(開始/終了)は
/// Android ネイティブ側(`ExternalTouchpadController`)が外部ディスプレイの実際の
/// 接続/切断イベントだけを根拠に所有する。この画面はその状態を観測して
/// 表示するだけで、マウント/アンマウントを起点にセッションを開始/終了しない
/// (以前はここで無条件に startSession/stopSession を呼んでおり、画面の
/// 再マウントのたびに外部ディスプレイがホームへ強制的に戻る不具合の原因になっていた)。
class TouchpadScreen extends ConsumerStatefulWidget {
  const TouchpadScreen({super.key});

  @override
  ConsumerState<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchpadScreenState extends ConsumerState<TouchpadScreen> {
  Timer? _oledTimer;
  Offset _oledShift = Offset.zero;
  final _random = Random();
  late final ExternalTouchpadApi _api;
  bool _brightnessMinimized = false;

  @override
  void initState() {
    super.initState();
    _api = ref.read(externalTouchpadApiProvider);
    unawaited(WakelockPlus.enable());
    ref.listenManual<bool>(
      settingsProvider.select(
        (settings) => settings.value?.oledProtection ?? false,
      ),
      (_, enabled) => _setOledProtectionEnabled(enabled),
      fireImmediately: true,
    );
    ref.listenManual<bool>(
      touchpadControllerProvider.select((state) => state.locked),
      (_, _) => _syncLockedBrightness(),
      fireImmediately: true,
    );
    ref.listenManual<bool>(
      settingsProvider.select(
        (settings) =>
            settings.value?.minimizeBrightnessWhileLocked ?? false,
      ),
      (_, _) => _syncLockedBrightness(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _oledTimer?.cancel();
    if (_brightnessMinimized) _setScreenBrightness(null);
    super.dispose();
  }

  void _setOledProtectionEnabled(bool enabled) {
    if (enabled && _oledTimer != null) return;
    _oledTimer?.cancel();
    _oledTimer = null;
    if (!enabled) {
      if (_oledShift != Offset.zero && mounted) {
        setState(() => _oledShift = Offset.zero);
      }
      return;
    }
    _oledTimer = Timer.periodic(AppDimens.oledShiftInterval, (_) {
      if (!mounted) return;
      setState(() {
        _oledShift = Offset(
          (_random.nextDouble() * 2 - 1) * AppDimens.oledMaxShiftPx,
          (_random.nextDouble() * 2 - 1) * AppDimens.oledMaxShiftPx,
        );
      });
    });
  }

  void _syncLockedBrightness() {
    final locked = ref.read(touchpadControllerProvider).locked;
    final minimizeWhileLocked =
        ref.read(settingsProvider).value?.minimizeBrightnessWhileLocked ??
        false;
    final shouldMinimize = locked && minimizeWhileLocked;
    if (shouldMinimize == _brightnessMinimized) return;
    _brightnessMinimized = shouldMinimize;
    _setScreenBrightness(shouldMinimize ? 0 : null);
  }

  void _setScreenBrightness(double? brightness) {
    unawaited(
      _api.setScreenBrightness(brightness).catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(touchpadControllerProvider);
    final controller = ref.read(touchpadControllerProvider.notifier);
    final accessibilityEnabled = ref.watch(
      appStatusProvider.select((status) => status.accessibilityEnabled),
    );
    final touchLockEnabled = ref.watch(
      settingsProvider.select((s) => s.value?.touchLockEnabled ?? false),
    );
    return Scaffold(
      body: SafeArea(
        // ステータスバー/カメラカットアウトと設定アイコンが重ならないようにする。
        child: Stack(
          children: [
            Transform.translate(
              offset: _oledShift,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        TouchSurface(state: state, controller: controller),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () => context.push('/settings'),
                          ),
                        ),
                        // タッチロック設定が ON かつ未ロックのときだけ表示する
                        // 「今すぐロック」ボタン(誤操作防止をすぐ発動したいケース用)。
                        if (touchLockEnabled && !state.locked)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: IconButton(
                              icon: const Icon(Icons.lock_outline),
                              tooltip: context.l10n.lockNowTooltip,
                              onPressed: controller.lockNow,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SystemNavBar(
                    enabled: accessibilityEnabled,
                    onBack: () => unawaited(_api.systemAction('back')),
                    onHome: () => unawaited(_api.systemAction('home')),
                    onAppList: () => unawaited(showAppListSheet(context)),
                  ),
                ],
              ),
            ),
            if (state.locked)
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => controller.handlePointerDown(
                  event.pointer,
                  event.localPosition,
                  event.timeStamp,
                ),
                onPointerMove: (event) => controller.handlePointerMove(
                  event.pointer,
                  event.localPosition,
                  event.timeStamp,
                ),
                onPointerUp: (event) => controller.handlePointerUp(
                  event.pointer,
                  event.localPosition,
                  event.timeStamp,
                ),
                onPointerCancel: (event) =>
                    controller.handlePointerCancel(event.pointer),
                child: LockOverlay(
                  holdProgress: state.unlockHoldProgress,
                  contentOffset: _oledShift,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
