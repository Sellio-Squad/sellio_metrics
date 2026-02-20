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
          'Sellio is a startup e-commerce platform that reimagines '
          'how people buy and sell online. We connect sellers and buyers '
          'in a seamless marketplace for both pre-owned and new goods, '
          'combining traditional e-commerce with modern thrifting culture.',
          style: AppTypography.body.copyWith(
            height: 1.8,
            color: scheme.body,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Our mission is to make online selling as easy as posting on '
          'social media while providing buyers with a curated, trustworthy '
          'shopping experience. We target the growing second-hand market '
          'in the MENA region, where sustainability meets affordability.',
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
            _AdvantageChip(emoji: '🎯', text: 'MENA-first approach'),
            _AdvantageChip(emoji: '♻️', text: 'Sustainability-driven'),
            _AdvantageChip(emoji: '🤖', text: 'AI-powered curation'),
            _AdvantageChip(emoji: '📱', text: 'Mobile-first design'),
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
          'Sellio differentiates itself through AI-powered product recommendations, '
          'integrated design generation tools, and a streamlined seller onboarding '
          'process that reduces listing time by 70%. Our scalable microservices '
          'architecture supports rapid growth, and our cross-platform Flutter apps '
          'ensure a consistent experience across iOS, Android, and Web.',
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
