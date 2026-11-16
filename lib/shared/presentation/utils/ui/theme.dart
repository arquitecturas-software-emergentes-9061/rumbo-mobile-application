import 'package:flutter/material.dart';

abstract final class RumboColors {
  static const background = Color(0xFFF9F9FF);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF3658E8);
  static const primaryDark = Color(0xFF0E3CD0);
  static const primaryContainer = Color(0xFFE8EEFF);
  static const textPrimary = Color(0xFF101C2E);
  static const textSecondary = Color(0xFF444655);
}

abstract final class RumboTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: RumboColors.primary,
      brightness: Brightness.light,
      surface: RumboColors.surface,
    ).copyWith(
      primary: RumboColors.primary,
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: RumboColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: RumboColors.background,
        foregroundColor: RumboColors.textPrimary,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: RumboColors.background,
        indicatorColor: RumboColors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? RumboColors.primaryDark
                : RumboColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          );
        }),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: RumboColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: RumboColors.textSecondary,
          fontSize: 15,
        ),
      ),
    );
  }
}
