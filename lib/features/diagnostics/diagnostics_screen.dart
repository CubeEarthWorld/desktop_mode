import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/platform/desktop_mode_channel.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../models/diagnostics_info.dart';

class _DeviceSummary {
  const _DeviceSummary({
    required this.androidRelease,
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
    required this.appVersion,
  });

  final String androidRelease;
  final int sdkInt;
  final String manufacturer;
  final String model;
  final String appVersion;
}

Future<_DeviceSummary> _loadDeviceSummary() async {
  final deviceInfo = await DeviceInfoPlugin().androidInfo;
  final packageInfo = await PackageInfo.fromPlatform();
  return _DeviceSummary(
    androidRelease: deviceInfo.version.release,
    sdkInt: deviceInfo.version.sdkInt,
    manufacturer: deviceInfo.manufacturer,
    model: deviceInfo.model,
    appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
  );
}

/// 診断画面。§8.6 に定義された全項目を表示し、「更新」で再取得する。
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  late Future<_DeviceSummary> _deviceSummary;
  late Future<DiagnosticsInfo> _diagnostics;

  @override
  void initState() {
    super.initState();
    _deviceSummary = _loadDeviceSummary();
    _diagnostics = ref.read(desktopModeApiProvider).getDiagnostics();
  }

  void _refresh() {
    setState(() {
      _diagnostics = ref.read(desktopModeApiProvider).getDiagnostics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('診断'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.screenPadding),
        children: [
          FutureBuilder<_DeviceSummary>(
            future: _deviceSummary,
            builder: (context, snapshot) {
              final device = snapshot.data;
              if (device == null) return const _Row(label: '端末', value: '読み込み中…');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(label: 'Android バージョン', value: '${device.androidRelease} (API ${device.sdkInt})'),
                  _Row(label: 'メーカー / モデル', value: '${device.manufacturer} / ${device.model}'),
                  _Row(label: 'アプリバージョン', value: device.appVersion),
                ],
              );
            },
          ),
          const Divider(color: AppColors.divider, height: AppDimens.spacingLarge * 2),
          FutureBuilder<DiagnosticsInfo>(
            future: _diagnostics,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final diagnostics = snapshot.data;
              if (diagnostics == null) {
                return Text(
                  '取得に失敗しました: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.foreground),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(
                    label: 'Accessibility',
                    value: diagnostics.accessibilityEnabled ? '有効' : '無効',
                  ),
                  _Row(
                    label: 'Secondary Display Feature',
                    value: diagnostics.hasSecondaryDisplayFeature ? 'あり' : 'なし',
                  ),
                  _Row(
                    label: 'Target Display ID',
                    value: diagnostics.targetDisplayId?.toString() ?? '未設定',
                  ),
                  _Row(
                    label: 'Display Bounds',
                    value: diagnostics.displayBounds == null
                        ? '-'
                        : '${diagnostics.displayBounds!.width}×${diagnostics.displayBounds!.height}',
                  ),
                  _Row(label: 'Overlay Active', value: diagnostics.overlayActive ? 'はい' : 'いいえ'),
                  _Row(label: 'Last Gesture Result', value: diagnostics.lastGestureResult),
                  _Row(label: 'Last Error', value: diagnostics.lastError ?? 'なし'),
                  const SizedBox(height: AppDimens.spacingMedium),
                  const Text('接続 Display 一覧', style: TextStyle(color: AppColors.accent)),
                  for (final display in diagnostics.displays)
                    _Row(
                      label: '#${display.id}${display.isDefault ? ' (default)' : ''}',
                      value: '${display.name}  ${display.widthPx}×${display.heightPx}',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: AppColors.disabled, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.foreground)),
          ),
        ],
      ),
    );
  }
}
