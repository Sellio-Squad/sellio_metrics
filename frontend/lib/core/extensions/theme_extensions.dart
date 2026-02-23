library;

import 'package:flutter/material.dart';
import '../theme/sellio_colors.dart';

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;


  SellioColorScheme get colors =>
      isDark ? SellioColors.dark : SellioColors.light;
}
