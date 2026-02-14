/// Sellio Metrics — Color Tokens
///
/// Uses the official Sellio brand palette.
/// Provides light/dark scheme instances via SellioColorScheme.
library;

import 'package:flutter/material.dart';

/// Semantic color scheme for the Sellio brand.
class SellioColorScheme {
  final Color authBackground;
  final Color primary;
  final Color primaryVariant;
  final Color secondary;
  final Color secondaryVariant;
  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color title;
  final Color body;
  final Color hint;
  final Color stroke;
  final Color onPrimary;
  final Color disabled;
  final Color red;
  final Color errorVariant;
  final Color green;
  final Color greenVariant;
  final Color redVariant;
  final Color purpleVariant;
  final Color semanticError;
  final Color neutralsHint;
  final List<Color> loadingDarkColors;
  final List<Color> loadingLightColors;
  final Color uploadImageTint;
  final Color shadowColor;

  const SellioColorScheme({
    this.authBackground = const Color(0xFF2C0113),
    required this.primary,
    required this.primaryVariant,
    required this.secondary,
    required this.secondaryVariant,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.title,
    required this.body,
    required this.hint,
    required this.stroke,
    required this.onPrimary,
    required this.disabled,
    required this.red,
    required this.errorVariant,
    required this.green,
    required this.greenVariant,
    required this.redVariant,
    required this.purpleVariant,
    required this.semanticError,
    required this.neutralsHint,
    required this.loadingDarkColors,
    required this.loadingLightColors,
    required this.uploadImageTint,
    required this.shadowColor,
  });
}

/// Central color definitions for the Sellio brand.
///
/// Access via [SellioColors.light] or [SellioColors.dark].
class SellioColors {
  SellioColors._();

  // ─── Brand schemes ────────────────────────────────────────

  static const light = SellioColorScheme(
    primary: Color(0xFF520826),
    primaryVariant: Color(0xFFFEF5F9),
    secondary: Color(0xFFF5A623),
    secondaryVariant: Color(0xFFFEF3E1),
    surfaceLow: Color(0xFFFFFFFF),
    surface: Color(0xFFF8F8F8),
    surfaceHigh: Color(0xFFE6E6E6),
    title: Color(0xDE1F1F1F),
    body: Color(0xA81F1F1F),
    hint: Color(0x611F1F1F),
    stroke: Color(0x1F1F1F1F),
    onPrimary: Color(0xDEFFFFFF),
    disabled: Color(0xFFE8EBED),
    red: Color(0xFFE54F40),
    errorVariant: Color(0xFFFEEDEC),
    green: Color(0xFF0D6620),
    greenVariant: Color(0xFFE0F5E5),
    redVariant: Color(0xFFFEEDEC),
    purpleVariant: Color(0xFFFEF5F9),
    semanticError: Color(0xFFCF3E30),
    neutralsHint: Color(0xFFBBBBBB),
    loadingDarkColors: [
      Color(0x1F520826),
      Color(0x80520826),
      Color(0xFF520826),
    ],
    loadingLightColors: [
      Color(0x1FFFFFFF),
      Color(0x80FFFFFF),
      Color(0xDEFFFFFF),
    ],
    uploadImageTint: Color(0x70000000),
    shadowColor: Color(0x1F520826),
  );

  static const dark = SellioColorScheme(
    primary: Color(0xFF520826),
    primaryVariant: Color(0xFFFEF5F9),
    secondary: Color(0xFFF5A623),
    secondaryVariant: Color(0xFFFEF3E1),
    surfaceLow: Color(0xFF1A1A2E),
    surface: Color(0xFF12121A),
    surfaceHigh: Color(0xFF2A2A3A),
    title: Color(0xDEFFFFFF),
    body: Color(0xA8FFFFFF),
    hint: Color(0x61FFFFFF),
    stroke: Color(0x1FFFFFFF),
    onPrimary: Color(0xDEFFFFFF),
    disabled: Color(0xFF3A3A4A),
    red: Color(0xFFE54F40),
    errorVariant: Color(0xFF3B1A18),
    green: Color(0xFF0D6620),
    greenVariant: Color(0xFF1A3A1F),
    redVariant: Color(0xFF3B1A18),
    purpleVariant: Color(0xFF2A1A2E),
    semanticError: Color(0xFFCF3E30),
    neutralsHint: Color(0xFF666666),
    loadingDarkColors: [
      Color(0x1F520826),
      Color(0x80520826),
      Color(0xFF520826),
    ],
    loadingLightColors: [
      Color(0x1FFFFFFF),
      Color(0x80FFFFFF),
      Color(0xDEFFFFFF),
    ],
    uploadImageTint: Color(0x70000000),
    shadowColor: Color(0x1F520826),
  );

  // ─── Product colors ───────────────────────────────────────

  static const Color productBlack = Colors.black;
  static const Color productWhite = Colors.white;

  // ─── Gradients ────────────────────────────────────────────

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF520826), Color(0xFF7A1040)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF3B0619), Color(0xFF520826)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Chart palette ────────────────────────────────────────

  static const List<Color> chartPalette = [
    Color(0xFF520826),
    Color(0xFFF5A623),
    Color(0xFF0D6620),
    Color(0xFFE54F40),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
  ];
}
