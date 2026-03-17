library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums/pr_type.dart';
import '../../../extensions/pr_type_presentation.dart';

class PrTypeBadge extends StatelessWidget {
  final PrType prType;

  const PrTypeBadge({super.key, required this.prType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: prType.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        prType.label,
        style: AppTypography.caption.copyWith(
          color: prType.color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
