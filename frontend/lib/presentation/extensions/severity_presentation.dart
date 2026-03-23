
import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/theme/sellio_colors.dart';
import 'package:sellio_metrics/domain/enums/severity.dart';

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
