import 'package:flutter/widgets.dart';

/// カラートークンの唯一の定義箇所(仕様 §8.1)。他のファイルは値を直接書かずここを参照する。
abstract final class AppColors {
  static const background = Color(0xFF000000);
  static const foreground = Color(0xFF9E9E9E);
  static const foregroundPressed = Color(0xFFD0D0D0);
  static const disabled = Color(0xFF4A4A4A);
  static const divider = Color(0xFF242424);
  static const accent = Color(0xFF448AFF);
  static const glow = Color(0x2EB4B4B4); // rgba(180,180,180,0.18)
  // グラデーション中心の発光色。実機での視認性を確保するため glow よりやや高い alpha。
  static const glowCenter = Color(0x59B4B4B4); // rgba(180,180,180,0.35)
}
