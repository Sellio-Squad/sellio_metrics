import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/about/about_section_header.dart';

class AboutVisionSection extends StatelessWidget {
  const AboutVisionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionHeader(
            title: l10n.aboutVision,
            icon: Icons.visibility_outlined,
            subtitle: 'Shaping the future of e-commerce in the MENA region.',
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.aboutVisionP1,
            style: AppTypography.body.copyWith(
              height: 1.8,
              color: scheme.body,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.aboutVisionP2,
            style: AppTypography.body.copyWith(
              height: 1.8,
              color: scheme.body,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ─── Advantage Chips ──────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _AdvantageChip(
                icon: LucideIcons.target,
                text: l10n.aboutVisionChipMena,
              ),
              _AdvantageChip(
                icon: LucideIcons.recycle,
                text: l10n.aboutVisionChipSustainability,
              ),
              _AdvantageChip(
                icon: LucideIcons.brain,
                text: l10n.aboutVisionChipAi,
              ),
              _AdvantageChip(
                icon: LucideIcons.smartphone,
                text: l10n.aboutVisionChipMobile,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // ─── Executive Summary ──────────────────────────────
          AboutSectionHeader(
            title: l10n.aboutExecutiveSummary,
            icon: Icons.summarize_outlined,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Callout card with accent bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: scheme.primaryVariant,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: SellioColors.primaryGradient,
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Text(
                      l10n.aboutSummaryBody,
                      style: AppTypography.body.copyWith(
                        height: 1.7,
                        color: scheme.body,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvantageChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdvantageChip({required this.icon, required this.text});

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
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
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