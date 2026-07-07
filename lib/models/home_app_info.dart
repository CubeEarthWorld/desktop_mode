import 'dart:typed_data';

/// 外部ディスプレイの「ホーム」として起動できるランチャーアプリ
/// (CATEGORY_HOME を持つアプリ)の情報(native → Flutter、読み取り専用)。
class HomeAppInfo {
  const HomeAppInfo({
    required this.packageName,
    required this.activityName,
    required this.label,
    this.iconPng,
  });

  factory HomeAppInfo.fromMap(Map<Object?, Object?> map) => HomeAppInfo(
    packageName: map['packageName']! as String,
    activityName: map['activityName']! as String,
    label: map['label']! as String,
    iconPng: map['iconPng'] == null
        ? null
        : Uint8List.fromList((map['iconPng'] as List<dynamic>).cast<int>()),
  );

  final String packageName;
  final String activityName;
  final String label;
  final Uint8List? iconPng;
}
