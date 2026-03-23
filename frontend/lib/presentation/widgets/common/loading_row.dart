import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

class LoadingRow extends StatelessWidget {
  final String label;
  final double size;

  const LoadingRow({
    super.key,
    required this.label,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: scheme.body),
          ),
        ),
      ],
    );
  }
}
