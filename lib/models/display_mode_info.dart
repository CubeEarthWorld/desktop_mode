/// 接続先ディスプレイが実際に対応している解像度/リフレッシュレートの組み合わせ
/// (native → Flutter、読み取り専用)。仮想ディスプレイを自作するのではなく、
/// 接続機器(HDMI/ワイヤレスディスプレイ等)が広告する既存のモードから選ぶ方式のため、
/// 選択肢は接続機器が対応する範囲に限られる。
class DisplayModeInfo {
  const DisplayModeInfo({
    required this.modeId,
    required this.widthPx,
    required this.heightPx,
    required this.refreshRate,
  });

  factory DisplayModeInfo.fromMap(Map<Object?, Object?> map) => DisplayModeInfo(
    modeId: map['modeId']! as int,
    widthPx: map['widthPx']! as int,
    heightPx: map['heightPx']! as int,
    refreshRate: (map['refreshRate']! as num).toDouble(),
  );

  final int modeId;
  final int widthPx;
  final int heightPx;
  final double refreshRate;
}
