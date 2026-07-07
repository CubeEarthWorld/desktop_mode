import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/platform/desktop_mode_channel.dart';
import 'core/theme/app_theme.dart';
import 'features/diagnostics/diagnostics_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/touchpad/touchpad_screen.dart';
import 'models/desktop_mode_event.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/touchpad', builder: (context, state) => const TouchpadScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/diagnostics', builder: (context, state) => const DiagnosticsScreen()),
  ],
);

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// アプリのルート。ダークテーマ固定 + go_router によるルーティング(仕様 §9)。
class DesktopModeApp extends ConsumerWidget {
  const DesktopModeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(desktopModeEventsProvider, (previous, next) {
      next.whenData((event) => _handleNavigationEvent(ref, event));
    });

    return MaterialApp.router(
      title: 'Desktop Touchpad',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}

/// sessionStarted → /touchpad(autoStart/Accessibility の判定は Android ネイティブ側
/// (`DesktopModeController.onDisplayAdded`)で完結しており、ここでは二重に判定しない)。
/// sessionStopped → / へ戻し、理由に応じて通知する(仕様 §9)。
void _handleNavigationEvent(WidgetRef ref, DesktopModeEvent event) {
  switch (event) {
    case SessionStartedEvent():
      _router.go('/touchpad');
    case SessionStoppedEvent(:final reason):
      switch (reason) {
        case 'displayRemoved':
          _router.go('/');
          _scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('外部ディスプレイの接続が切れました')),
          );
        case 'manualStop':
          _router.go('/');
        default:
          // 想定外の理由でセッションが終了した場合も、無言で追い出さず通知する。
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('セッションが予期せず終了しました ($reason)')),
          );
      }
    case DisplayAddedEvent():
    case DisplayRemovedEvent():
    case DisplayChangedEvent():
    case AccessibilityStateChangedEvent():
    case NativeErrorEvent():
      break;
  }
}
