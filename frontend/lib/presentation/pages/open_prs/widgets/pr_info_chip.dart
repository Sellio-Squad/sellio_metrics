
import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';

class PrInfoChip extends StatelessWidget {
  final String text;
  final IconData? icon;

  const PrInfoChip({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: scheme.hint),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
