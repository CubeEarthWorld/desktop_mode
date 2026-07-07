import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/desktop_mode_api.dart';
import '../../../core/platform/desktop_mode_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../models/home_app_info.dart';

/// インストール済みアプリの一覧をドロワー状に開き、選択したアプリを
/// 外部ディスプレイ上で起動するモーダルシート。「アプリ履歴」ボタンの代わりに、
/// 外部ディスプレイで直接使いたい任意のアプリへすぐアクセスできるようにする。
Future<void> showAppListSheet(BuildContext context, WidgetRef ref) {
  final api = ref.read(desktopModeApiProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF0A0A0A),
    builder: (sheetContext) => _AppListSheetContent(api: api),
  );
}

class _AppListSheetContent extends StatefulWidget {
  const _AppListSheetContent({required this.api});

  final DesktopModeApi api;

  @override
  State<_AppListSheetContent> createState() => _AppListSheetContentState();
}

class _AppListSheetContentState extends State<_AppListSheetContent> {
  late final Future<List<HomeAppInfo>> _appsFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _appsFuture = widget.api.getInstalledApps();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: AppDimens.screenPadding,
          right: AppDimens.screenPadding,
          bottom: bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppDimens.spacingSmall),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spacingMedium),
            const Text(
              'アプリ一覧',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            TextField(
              style: const TextStyle(color: AppColors.foreground),
              decoration: const InputDecoration(
                hintText: '検索',
                hintStyle: TextStyle(color: AppColors.disabled),
                prefixIcon: Icon(Icons.search, color: AppColors.disabled),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            Expanded(
              child: FutureBuilder<List<HomeAppInfo>>(
                future: _appsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final apps = snapshot.data!
                      .where((a) => a.label.toLowerCase().contains(_query))
                      .toList();
                  if (apps.isEmpty) {
                    return const Center(
                      child: Text(
                        '該当するアプリがありません',
                        style: TextStyle(color: AppColors.disabled),
                      ),
                    );
                  }
                  return GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return _AppGridTile(
                        app: app,
                        onTap: () {
                          unawaited(widget.api.launchApp(app.packageName, app.activityName));
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppGridTile extends StatelessWidget {
  const _AppGridTile({required this.app, required this.onTap});

  final HomeAppInfo app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.cornerRadius),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: app.iconPng != null
                  ? Image.memory(
                      app.iconPng!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _defaultAppIcon(),
                    )
                  : _defaultAppIcon(),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            Text(
              app.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// アイコン取得に失敗した、または未対応のアプリ用のプレースホルダー。
  Widget _defaultAppIcon() => const SizedBox(
    width: 48,
    height: 48,
    child: Icon(Icons.apps, color: AppColors.disabled, size: 32),
  );
}
