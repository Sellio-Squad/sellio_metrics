import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class AboutHero extends StatelessWidget {
  const AboutHero({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: SellioColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryVariant,
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              'v1.0 — Early Access',
              style: AppTypography.caption.copyWith(
                color: scheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.aboutSellio,
            style: AppTypography.headline.copyWith(
              color: scheme.title,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              l10n.aboutTagline,
              style: AppTypography.body.copyWith(
                color: scheme.hint,
                fontSize: 15,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _HeroStat(value: '3', label: l10n.aboutApps),
              _HeroStat(value: '6+', label: l10n.aboutKeyFeatures),
              _HeroStat(value: '4', label: l10n.aboutTechStack),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;

  const _HeroStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.kpiValue.copyWith(
            color: scheme.primary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: scheme.hint,
          ),
        ),
      ],
    );
  }
}