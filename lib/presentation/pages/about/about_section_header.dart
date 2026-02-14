/// Sellio Metrics — Reusable Section Header for About page
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';

class AboutSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const AboutSectionHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.title.copyWith(color: scheme.title),
        ),
      ],
    );
  }
}
