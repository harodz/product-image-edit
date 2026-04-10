import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppTokens.background,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppTokens.primary,
        onPrimary: Color(0xFF00407D),
        secondary: AppTokens.secondary,
        tertiary: AppTokens.tertiary,
        error: AppTokens.error,
        surface: AppTokens.surface,
        onSurface: AppTokens.onBackground,
        outline: AppTokens.outline,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Inter',
        bodyColor: AppTokens.onBackground,
        displayColor: AppTokens.onBackground,
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surfaceLow,
        foregroundColor: AppTokens.onBackground,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: BorderSide(color: AppTokens.outlineVariant.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: BorderSide(color: AppTokens.outlineVariant.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          borderSide: const BorderSide(color: AppTokens.primaryDim, width: 1.2),
        ),
      ),
    );
  }
}
