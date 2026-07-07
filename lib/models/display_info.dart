/// 外部ディスプレイ情報(native → Flutter、読み取り専用)。
class DisplayInfo {
  const DisplayInfo({
    required this.id,
    required this.name,
    required this.widthPx,
    required this.heightPx,
    required this.densityDpi,
    required this.isDefault,
  });

  factory DisplayInfo.fromMap(Map<Object?, Object?> map) => DisplayInfo(
    id: map['id']! as int,
    name: map['name']! as String,
    widthPx: map['widthPx']! as int,
    heightPx: map['heightPx']! as int,
    densityDpi: (map['densityDpi']! as num).toDouble(),
    isDefault: map['isDefault']! as bool,
  );

  final int id;
  final String name;
  final int widthPx;
  final int heightPx;
  final double densityDpi;
  final bool isDefault;
}
