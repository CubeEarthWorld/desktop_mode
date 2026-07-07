import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ダークテーマのみ(モノクロ + 青アクセント)。
ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.foreground,
    error: AppColors.foreground,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.divider,
    iconTheme: const IconThemeData(color: AppColors.foreground),
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: AppColors.foreground,
      displayColor: AppColors.foreground,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.accent : AppColors.foreground,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.accent.withValues(alpha: 0.5)
            : AppColors.disabled,
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.disabled,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.foreground,
      elevation: 0,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0A0A0A)),
  );
}
