import 'package:external_touchpad/features/touchpad/widgets/lock_overlay.dart';
import 'package:external_touchpad/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dims and shifts the lock content for OLED protection', (
    tester,
  ) async {
    const offset = Offset(6, -4);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LockOverlay(holdProgress: 0.25, contentOffset: offset),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    final transform = tester.widget<Transform>(find.byType(Transform));
    final translation = transform.transform.getTranslation();

    expect(opacity.opacity, 0.5);
    expect(translation.x, offset.dx);
    expect(translation.y, offset.dy);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Hold to unlock'), findsOneWidget);
  });
}
