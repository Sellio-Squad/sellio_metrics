library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart' show HuxTheme;

/// Sellio theme definitions (light/dark).
/// Exposed via the design system; backed by Hux theme.
class SellioThemes {
  SellioThemes._();

  static ThemeData get lightTheme => HuxTheme.lightTheme;
  static ThemeData get darkTheme => HuxTheme.darkTheme;
}
