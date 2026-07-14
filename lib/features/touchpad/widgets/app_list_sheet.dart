import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/external_touchpad_channel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../l10n/l10n.dart';
import '../../../models/home_app_info.dart';

/// Native keeps a short-lived result cache, while auto-dispose releases PNG
/// memory after the sheet closes.
final _installedAppsProvider = FutureProvider.autoDispose<List<HomeAppInfo>>((
  ref,
) {
  return ref.read(externalTouchpadApiProvider).getInstalledApps();
});

typedef _AppComponentKey = ({String packageName, String activityName});

final _appIconProvider = FutureProvider.autoDispose
    .family<Uint8List?, _AppComponentKey>((ref, component) {
      return ref
          .read(externalTouchpadApiProvider)
          .getAppIcon(component.packageName, component.activityName);
    });

Future<void> showAppListSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceElevated,
    builder: (_) => const _AppListSheetContent(),
  );
}

class _AppListSheetContent extends ConsumerStatefulWidget {
  const _AppListSheetContent();

  @override
  ConsumerState<_AppListSheetContent> createState() =>
      _AppListSheetContentState();
}

class _AppListSheetContentState extends ConsumerState<_AppListSheetContent> {
  final _searchFocusNode = FocusNode(debugLabel: 'appListSearch');
  String _query = '';

  @override
  void initState() {
    super.initState();
    // タッチパッド操作でソフトキーボードがグローバルに隠されたままだと、この検索欄が
    // オートフォーカスしてもキーボードが開かない(setShowMode はディスプレイ単位でなく
    // システム全体に効くため)。フォーカスイベント頼みだと開かないことがあるので、
    // ここで能動的に解除しておく。
    unawaited(
      ref
          .read(externalTouchpadApiProvider)
          .restoreSoftKeyboard()
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsValue = ref.watch(_installedAppsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
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
            Text(
              context.l10n.appListTitle,
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            TextField(
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.foreground),
              decoration: InputDecoration(
                hintText: context.l10n.searchHint,
                hintStyle: const TextStyle(color: AppColors.disabled),
                prefixIcon: const Icon(Icons.search, color: AppColors.disabled),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: AppDimens.spacingSmall),
            Expanded(
              child: appsValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(_installedAppsProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.reloadAppList),
                  ),
                ),
                data: (allApps) {
                  final apps = allApps
                      .where((app) => app.label.toLowerCase().contains(_query))
                      .toList(growable: false);
                  if (apps.isEmpty) {
                    return Center(
                      child: Text(
                        context.l10n.noMatchingApps,
                        style: const TextStyle(color: AppColors.disabled),
                      ),
                    );
                  }

                  return GridView.builder(
                    controller: scrollController,
                    scrollCacheExtent: const ScrollCacheExtent.pixels(96),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(
                      top: AppDimens.spacingSmall,
                      bottom: AppDimens.spacingLarge,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 88,
                        ),
                    itemCount: apps.length,
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      return _AppGridItem(
                        key: ValueKey('${app.packageName}/${app.activityName}'),
                        app: app,
                        onLaunch: () {
                          unawaited(
                            ref
                                .read(externalTouchpadApiProvider)
                                .launchApp(app.packageName, app.activityName),
                          );
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

class _AppGridItem extends StatelessWidget {
  const _AppGridItem({super.key, required this.app, required this.onLaunch});

  final HomeAppInfo app;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: app.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onLaunch,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AppIcon(app: app),
              const SizedBox(height: 3),
              Text(
                app.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.foreground,
                  fontSize: 10,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends ConsumerWidget {
  const _AppIcon({required this.app});

  final HomeAppInfo app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final component = (
      packageName: app.packageName,
      activityName: app.activityName,
    );
    final bytes = app.iconPng ?? ref.watch(_appIconProvider(component)).value;
    if (bytes == null) return _fallback();
    return Image.memory(
      bytes,
      width: 48,
      height: 48,
      cacheWidth: 96,
      cacheHeight: 96,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => const SizedBox(
    width: 48,
    height: 48,
    child: Icon(Icons.apps, size: 40, color: AppColors.disabled),
  );
}
