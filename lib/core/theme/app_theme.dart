/// Sellio Metrics Dashboard — App Theme Configuration
///
/// Extends Hux theme with Sellio brand colors and custom design tokens.
library;

import 'package:flutter/material.dart';

/// Sellio brand color palette
class SellioColors {
  const SellioColors._();

  // Primary gradient
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color primaryViolet = Color(0xFF8B5CF6);

  // Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Severity colors
  static const Color severityHigh = Color(0xFFEF4444);
  static const Color severityMedium = Color(0xFFF59E0B);
  static const Color severityLow = Color(0xFF10B981);

  // Status colors
  static const Color merged = Color(0xFF8B5CF6);
  static const Color pending = Color(0xFFF59E0B);
  static const Color closed = Color(0xFFEF4444);
  static const Color approved = Color(0xFF10B981);

  // KPI accent colors
  static const Color kpiFuchsia = Color(0xFFD946EF);
  static const Color kpiPurple = Color(0xFFA855F7);
  static const Color kpiBlue = Color(0xFF3B82F6);
  static const Color kpiCyan = Color(0xFF06B6D4);
  static const Color kpiPink = Color(0xFFEC4899);

  // Chart palette
  static const List<Color> chartPalette = [
    primaryIndigo,
    primaryPurple,
    success,
    warning,
    info,
    kpiFuchsia,
    kpiCyan,
    kpiPink,
  ];

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryIndigo, primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4C1D95)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Spacing tokens
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Border radius tokens
class AppRadius {
  const AppRadius._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// App typography
class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Manrope';

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle kpiValue = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
  );
}
