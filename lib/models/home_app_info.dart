import 'dart:typed_data';

/// 外部ディスプレイへ起動できる Activity の情報。
class HomeAppInfo {
  const HomeAppInfo({
    required this.packageName,
    required this.activityName,
    required this.label,
    this.iconPng,
  });

  factory HomeAppInfo.fromMap(Map<Object?, Object?> map) {
    final rawIcon = map['iconPng'];
    return HomeAppInfo(
      packageName: map['packageName']! as String,
      activityName: map['activityName']! as String,
      label: map['label']! as String,
      iconPng: rawIcon == null
          ? null
          : rawIcon is Uint8List
          ? rawIcon
          : Uint8List.fromList((rawIcon as List<dynamic>).cast<int>()),
    );
  }

  final String packageName;
  final String activityName;
  final String label;
  final Uint8List? iconPng;
}
