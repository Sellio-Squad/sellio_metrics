import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';

class AboutSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const AboutSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Accent icon with background
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primaryVariant,
                borderRadius: AppRadius.smAll,
              ),
              child: Center(
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.title.copyWith(color: scheme.title),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(left: 48), // aligned with title text
            child: Text(
              subtitle!,
              style: AppTypography.body.copyWith(
                color: scheme.hint,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // Decorative accent line
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            gradient: SellioColors.primaryGradient,
            borderRadius: AppRadius.smAll,
          ),
        ),
      ],
    );
  }
}