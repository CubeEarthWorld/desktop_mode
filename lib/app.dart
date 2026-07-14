import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/route_observer.dart';
import 'core/platform/external_touchpad_channel.dart';
import 'core/theme/app_theme.dart';
import 'features/diagnostics/diagnostics_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/touchpad/touchpad_screen.dart';
import 'l10n/l10n.dart';
import 'models/external_touchpad_event.dart';

final _router = GoRouter(
  initialLocation: '/',
  observers: [routeObserver],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/touchpad',
      builder: (context, state) => const TouchpadScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/diagnostics',
      builder: (context, state) => const DiagnosticsScreen(),
    ),
  ],
);

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// アプリのルート。ダークテーマ固定 + go_router によるルーティング(仕様 §9)。
class ExternalTouchpadApp extends ConsumerWidget {
  const ExternalTouchpadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(externalTouchpadEventsProvider, (previous, next) {
      next.whenData((event) => _handleNavigationEvent(ref, event));
    });

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    );
  }
}

void _showSnackBar(String Function(AppLocalizations l10n) message) {
  final messenger = _scaffoldMessengerKey.currentState;
  final context = messenger?.context;
  if (messenger == null || context == null) return;
  messenger.showSnackBar(SnackBar(content: Text(message(context.l10n))));
}

/// sessionStarted → /touchpad(autoStart/Accessibility の判定は Android ネイティブ側
/// (`ExternalTouchpadController.onDisplayAdded`)で完結しており、ここでは二重に判定しない)。
/// sessionStopped → / へ戻し、理由に応じて通知する(仕様 §9)。
void _handleNavigationEvent(WidgetRef ref, ExternalTouchpadEvent event) {
  switch (event) {
    case SessionStartedEvent():
      _router.go('/touchpad');
    case SessionStoppedEvent(:final reason):
      switch (reason) {
        case 'displayRemoved':
          _router.go('/');
          _showSnackBar((l10n) => l10n.displayDisconnected);
        case 'manualStop':
          _router.go('/');
        default:
          // 想定外の理由でセッションが終了した場合も、無言で追い出さず通知する。
          _showSnackBar((l10n) => l10n.sessionEndedUnexpectedly(reason));
      }
    case DisplayAddedEvent():
    case DisplayRemovedEvent():
    case DisplayChangedEvent():
    case AccessibilityStateChangedEvent():
    case NativeErrorEvent():
      break;
  }
}
