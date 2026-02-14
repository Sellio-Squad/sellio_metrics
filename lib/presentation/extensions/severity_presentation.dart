/// Sellio Metrics — Severity Presentation Extension
///
/// Maps domain Severity values to UI colors and icons.
/// Keeps framework concerns out of the domain layer.
library;

import 'package:flutter/material.dart';

import '../../core/theme/sellio_colors.dart';
import '../../domain/enums/severity.dart';

extension SeverityPresentation on Severity {
  Color get color => switch (this) {
        Severity.high => SellioColors.light.red,
        Severity.medium => SellioColors.light.secondary,
        Severity.low => SellioColors.light.green,
      };

  IconData get icon => switch (this) {
        Severity.high => Icons.error_outline,
        Severity.medium => Icons.warning_amber_outlined,
        Severity.low => Icons.info_outline,
      };
}
