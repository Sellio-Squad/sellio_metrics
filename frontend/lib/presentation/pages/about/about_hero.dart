/// Sellio Metrics — About Hero Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class AboutHero extends StatelessWidget {
  const AboutHero({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: SellioColors.primaryGradient,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.aboutSellio,
            style: AppTypography.heading.copyWith(color: scheme.onPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.aboutTagline,
            style: AppTypography.body.copyWith(
              color: scheme.onPrimary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
