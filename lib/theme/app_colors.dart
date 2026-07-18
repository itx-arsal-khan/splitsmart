import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary: Modern Indigo
  static const Color primary = Color(0xFF6366F1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE0E7FF);
  static const Color onPrimaryContainer = Color(0xFF312E81);

  // Secondary: Teal/Mint for success/money
  static const Color secondary = Color(0xFF14B8A6);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFCCFBF1);
  static const Color onSecondaryContainer = Color(0xFF115E59);

  // Tertiary: Coral for accents/alerts
  static const Color tertiary = Color(0xFFF43F5E);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFE4E6);
  static const Color onTertiaryContainer = Color(0xFF881337);

  // Error
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  // Light Mode Surfaces
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightSurfaceVariant = Color(0xFFE2E8F0);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFCBD5E1);

  // Dark Mode Surfaces
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkOutline = Color(0xFF334155);

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceVariant,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF818CF8), // Lighter indigo for dark mode
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF3730A3),
    onPrimaryContainer: Color(0xFFE0E7FF),
    secondary: Color(0xFF2DD4BF), // Lighter teal
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF0F766E),
    onSecondaryContainer: Color(0xFFCCFBF1),
    tertiary: Color(0xFFFB7185), // Lighter coral
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF9F1239),
    onTertiaryContainer: Color(0xFFFFE4E6),
    error: Color(0xFFF87171),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: darkSurface,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceVariant,
    onSurfaceVariant: darkOnSurfaceVariant,
    outline: darkOutline,
  );
}
