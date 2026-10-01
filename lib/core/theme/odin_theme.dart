import 'package:flutter/material.dart';

import 'odin_colors.dart';

abstract final class OdinTheme {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: OdinColors.cyan600,
      onPrimary: OdinColors.white,
      secondary: OdinColors.cyan500,
      onSecondary: OdinColors.white,
      surface: OdinColors.white,
      onSurface: OdinColors.zinc900,
      onSurfaceVariant: OdinColors.zinc600,
      outline: OdinColors.zinc300,
      outlineVariant: OdinColors.zinc200,
      surfaceContainerHighest: OdinColors.zinc100,
    );
    return _build(scheme, OdinColors.zinc100);
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: OdinColors.cyan400,
      onPrimary: OdinColors.zinc950,
      secondary: OdinColors.cyan500,
      onSecondary: OdinColors.zinc950,
      surface: OdinColors.zinc900,
      onSurface: OdinColors.zinc100,
      onSurfaceVariant: OdinColors.zinc400,
      outline: OdinColors.zinc700,
      outlineVariant: OdinColors.zinc800,
      surfaceContainerHighest: OdinColors.zinc800,
    );
    return _build(scheme, OdinColors.zinc950);
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
