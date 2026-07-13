/// 寸法・タイミングトークンの唯一の定義箇所。
abstract final class AppDimens {
  static const bottomNavHeight = 80.0;
  static const crosshairSize = 24.0;
  static const crosshairStrokeWidth = 1.0;
  static const touchGlowRadius = 32.0;
  static const touchGlowFadeOutMs = 300;
  static const screenPadding = 16.0;
  static const spacingSmall = 8.0;
  static const spacingMedium = 16.0;
  static const spacingLarge = 24.0;
  static const cornerRadius = 12.0;
  static const touchLockHoldMs = 1000;
  // ロック解除ホールド中にこの距離(論理px)を超えて指が動いたら解除失敗にする。
  static const touchLockUnlockMoveSlop = 12.0;
  static const oledShiftInterval = Duration(minutes: 3);
  static const oledMaxShiftPx = 8.0;
}
