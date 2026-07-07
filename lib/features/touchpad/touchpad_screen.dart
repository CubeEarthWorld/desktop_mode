import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/platform/app_status_provider.dart';
import '../../core/platform/desktop_mode_channel.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_dimens.dart';
import 'touchpad_controller.dart';
import 'widgets/app_list_sheet.dart';
import 'widgets/lock_overlay.dart';
import 'widgets/system_nav_bar.dart';
import 'widgets/touch_surface.dart';

/// 本体画面のタッチパッド UI。セッションのライフサイクル(開始/終了)は
/// Android ネイティブ側(`DesktopModeController`)が外部ディスプレイの実際の
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

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable());
    _maybeStartOledProtection();
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    _oledTimer?.cancel();
    super.dispose();
  }

  void _maybeStartOledProtection() {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    if (!settings.oledProtection) return;
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(touchpadControllerProvider);
    final controller = ref.read(touchpadControllerProvider.notifier);
    final accessibilityEnabled = ref.watch(
      appStatusProvider.select((status) => status.accessibilityEnabled),
    );
    final api = ref.read(desktopModeApiProvider);

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
                      ],
                    ),
                  ),
                  SystemNavBar(
                    enabled: accessibilityEnabled,
                    onBack: () => unawaited(api.systemAction('back')),
                    onHome: () => unawaited(api.systemAction('home')),
                    onAppList: () => unawaited(showAppListSheet(context, ref)),
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
                onPointerUp: (event) => controller.handlePointerUp(event.pointer, event.timeStamp),
                onPointerCancel: (event) => controller.handlePointerCancel(event.pointer),
                child: LockOverlay(holdProgress: state.unlockHoldProgress),
              ),
          ],
        ),
      ),
    );
  }
}
