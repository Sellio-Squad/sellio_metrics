/// Sellio Metrics — PrType Presentation Extension
///
/// Maps domain PrType values to UI colors.
/// Keeps framework concerns out of the domain layer.
library;

import 'package:flutter/material.dart';

import '../../core/theme/sellio_colors.dart';
import '../../domain/enums/pr_type.dart';

extension PrTypePresentation on PrType {
  Color get color => switch (this) {
        PrType.feature => SellioColors.light.green,
        PrType.fix => SellioColors.light.red,
        PrType.refactor => const Color(0xFF3B82F6),
        PrType.chore => const Color(0xFF6B7280),
        PrType.docs => const Color(0xFF14B8A6),
        PrType.ci => SellioColors.light.secondary,
        PrType.test => const Color(0xFF8B5CF6),
        PrType.style => const Color(0xFFEC4899),
        PrType.other => const Color(0xFF64748B),
      };
}
