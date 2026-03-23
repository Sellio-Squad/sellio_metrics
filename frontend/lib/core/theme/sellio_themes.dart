
import 'package:flutter/material.dart';
import 'package:hux/hux.dart' show HuxTheme;
import 'package:sellio_metrics/core/theme/sellio_colors.dart';

/// Sellio theme definitions (light/dark).
/// Light uses Hux; dark uses enhanced Sellio design system colors.
class SellioThemes {
  SellioThemes._();

  static ThemeData get lightTheme => HuxTheme.lightTheme;

  static ThemeData get darkTheme {
    final c = SellioColors.dark;
    final colorScheme = ColorScheme.dark(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryVariant,
      onPrimaryContainer: c.onPrimary,
      secondary: c.secondary,
      onSecondary: const Color(0xFF1A1A1A),
      secondaryContainer: c.secondaryVariant,
      onSecondaryContainer: c.secondary,
      tertiary: c.green,
      onTertiary: c.onPrimary,
      error: c.semanticError,
      onError: c.onPrimary,
      surface: c.surface,
      onSurface: c.title,
      onSurfaceVariant: c.body,
      outline: c.stroke,
      shadow: c.shadowColor,
      surfaceContainerHighest: c.surfaceHigh,
    );
    return HuxTheme.darkTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.surface,
      cardColor: c.surfaceHigh,
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceHigh,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
