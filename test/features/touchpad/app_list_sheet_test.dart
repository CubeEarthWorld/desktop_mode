import 'dart:typed_data';

import 'package:external_touchpad/core/platform/external_touchpad_channel.dart';
import 'package:external_touchpad/features/touchpad/widgets/app_list_sheet.dart';
import 'package:external_touchpad/l10n/generated/app_localizations.dart';
import 'package:external_touchpad/models/home_app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExternalTouchpadChannel extends ExternalTouchpadChannel {
  @override
  Future<List<HomeAppInfo>> getInstalledApps() async => const [
    HomeAppInfo(
      packageName: 'com.example.app',
      activityName: '.MainActivity',
      label: 'Example',
    ),
  ];

  @override
  Future<Uint8List?> getAppIcon(
    String packageName,
    String activityName,
  ) async => null;
}

void main() {
  testWidgets('search autofocuses without a window-size control', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          externalTouchpadApiProvider.overrideWithValue(
            _FakeExternalTouchpadChannel(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppListSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, true);
    expect(field.focusNode?.hasFocus, true);
    expect(find.byIcon(Icons.aspect_ratio), findsNothing);
    expect(find.text('Example'), findsOneWidget);
  });
}
