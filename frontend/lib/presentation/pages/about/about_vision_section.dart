/// Sellio Metrics — About Vision Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../presentation/pages/about/about_section_header.dart';

class AboutVisionSection extends StatelessWidget {
  const AboutVisionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AboutSectionHeader(
          title: l10n.aboutVision,
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aboutVisionP1,
          style: AppTypography.body.copyWith(
            height: 1.8,
            color: scheme.body,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.aboutVisionP2,
          style: AppTypography.body.copyWith(
            height: 1.8,
            color: scheme.body,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _AdvantageChip(emoji: '🎯', text: l10n.aboutVisionChipMena),
            _AdvantageChip(emoji: '♻️', text: l10n.aboutVisionChipSustainability),
            _AdvantageChip(emoji: '🤖', text: l10n.aboutVisionChipAi),
            _AdvantageChip(emoji: '📱', text: l10n.aboutVisionChipMobile),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Executive Summary
        AboutSectionHeader(
          title: l10n.aboutExecutiveSummary,
          icon: Icons.summarize_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aboutSummaryBody,
          style: AppTypography.body.copyWith(
            height: 1.7,
            color: scheme.body,
          ),
        ),
      ],
    );
  }
}

class _AdvantageChip extends StatelessWidget {
  final String emoji;
  final String text;

  const _AdvantageChip({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: AppTypography.body.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
