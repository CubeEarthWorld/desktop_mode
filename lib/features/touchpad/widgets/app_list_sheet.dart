import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/external_touchpad_channel.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../l10n/l10n.dart';
import '../../../models/app_window_mode.dart';
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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final appsValue = ref.watch(_installedAppsProvider);
    // Watching settings once keeps mode badges and popup selections current.
    final settings = ref.watch(settingsProvider).value;

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
                      final mode =
                          settings?.windowModeFor(
                            app.packageName,
                            app.activityName,
                          ) ??
                          AppWindowMode.auto;
                      final icon = ref
                          .watch(
                            _appIconProvider((
                              packageName: app.packageName,
                              activityName: app.activityName,
                            )),
                          )
                          .value;
                      return _AppGridItem(
                        app: app,
                        iconPng: app.iconPng ?? icon,
                        mode: mode,
                        onLaunch: () {
                          unawaited(
                            ref
                                .read(externalTouchpadApiProvider)
                                .launchApp(app.packageName, app.activityName),
                          );
                          Navigator.of(context).pop();
                        },
                        onModeSelected: (selected) =>
                            _setWindowMode(app, selected),
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

  Future<void> _setWindowMode(HomeAppInfo app, AppWindowMode mode) async {
    await ref
        .read(settingsProvider.notifier)
        .updateSettings(
          (settings) =>
              settings.withWindowMode(app.packageName, app.activityName, mode),
        );
  }
}

class _AppGridItem extends StatelessWidget {
  const _AppGridItem({
    required this.app,
    required this.iconPng,
    required this.mode,
    required this.onLaunch,
    required this.onModeSelected,
  });

  final HomeAppInfo app;
  final Uint8List? iconPng;
  final AppWindowMode mode;
  final VoidCallback onLaunch;
  final ValueChanged<AppWindowMode> onModeSelected;

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
              SizedBox(
                width: 56,
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _AppIcon(iconPng: iconPng),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: PopupMenuButton<AppWindowMode>(
                        tooltip: context.l10n.windowModeTooltip,
                        initialValue: mode,
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        icon: Icon(
                          Icons.aspect_ratio,
                          size: 16,
                          color: mode == AppWindowMode.auto
                              ? AppColors.disabled
                              : AppColors.foreground,
                        ),
                        onSelected: onModeSelected,
                        itemBuilder: (menuContext) => AppWindowMode.values
                            .map(
                              (value) => PopupMenuItem(
                                value: value,
                                child: Text(
                                  _windowModeLabel(menuContext.l10n, value),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
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

  static String _windowModeLabel(AppLocalizations l10n, AppWindowMode mode) =>
      switch (mode) {
        AppWindowMode.auto => l10n.windowModeAuto,
        AppWindowMode.phonePortrait => l10n.windowModePhonePortrait,
        AppWindowMode.phoneLandscape => l10n.windowModePhoneLandscape,
        AppWindowMode.fullExternal => l10n.windowModeFullExternal,
      };
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.iconPng});

  final Uint8List? iconPng;

  @override
  Widget build(BuildContext context) {
    final bytes = iconPng;
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
