/// Sellio Metrics — About Features Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/design_system.dart';
import 'about_section_header.dart';

class AboutFeaturesSection extends StatelessWidget {
  const AboutFeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final features = [
      'Multi-vendor e-commerce marketplace',
      'Thrifting & pre-owned goods',
      'AI-powered design generation',
      'Real-time analytics dashboard',
      'Scalable microservices backend',
      'Cross-platform Flutter apps',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AboutSectionHeader(
          title: 'Key Features',
          icon: Icons.star_outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children:
              features.map((f) => _FeatureChip(text: f)).toList(),
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String text;

  const _FeatureChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryVariant,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, color: scheme.green, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: AppTypography.body.copyWith(color: scheme.title),
          ),
        ],
      ),
    );
  }
}
