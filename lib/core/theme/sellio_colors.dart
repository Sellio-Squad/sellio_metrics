/// Sellio Metrics — Color Tokens
library;

import 'package:flutter/material.dart';

class SellioColors {
  const SellioColors._();

  // Primary gradient
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color primaryViolet = Color(0xFF8B5CF6);

  // Backgrounds
  static const Color darkBackground = Color(0xFF12121A);
  static const Color lightBackground = Color(0xFFF5F5F7);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Text
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Grays
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray700 = Color(0xFF374151);

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
