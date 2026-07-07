import 'display_info.dart';

/// 診断画面表示用の外部ディスプレイ境界(物理px)。
class DisplayBounds {
  const DisplayBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory DisplayBounds.fromMap(Map<Object?, Object?> map) => DisplayBounds(
    left: map['left']! as int,
    top: map['top']! as int,
    right: map['right']! as int,
    bottom: map['bottom']! as int,
  );

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
}

/// `getDiagnostics()` の戻り値(仕様 §4.2 Diagnostics に対応)。
class DiagnosticsInfo {
  const DiagnosticsInfo({
    required this.accessibilityEnabled,
    required this.displays,
    required this.targetDisplayId,
    required this.displayBounds,
    required this.hasSecondaryDisplayFeature,
    required this.overlayActive,
    required this.lastGestureResult,
    required this.lastError,
  });

  factory DiagnosticsInfo.fromMap(Map<Object?, Object?> map) => DiagnosticsInfo(
    accessibilityEnabled: map['accessibilityEnabled'] as bool? ?? false,
    displays: (map['displays'] as List<Object?>? ?? const [])
        .map((e) => DisplayInfo.fromMap(e! as Map<Object?, Object?>))
        .toList(),
    targetDisplayId: map['targetDisplayId'] as int?,
    displayBounds: map['displayBounds'] == null
        ? null
        : DisplayBounds.fromMap(map['displayBounds']! as Map<Object?, Object?>),
    hasSecondaryDisplayFeature: map['hasSecondaryDisplayFeature'] as bool? ?? false,
    overlayActive: map['overlayActive'] as bool? ?? false,
    lastGestureResult: map['lastGestureResult'] as String? ?? 'none',
    lastError: map['lastError'] as String?,
  );

  final bool accessibilityEnabled;
  final List<DisplayInfo> displays;
  final int? targetDisplayId;
  final DisplayBounds? displayBounds;
  final bool hasSecondaryDisplayFeature;
  final bool overlayActive;
  final String lastGestureResult;
  final String? lastError;
}
