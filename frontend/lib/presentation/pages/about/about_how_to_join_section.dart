import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/about/about_section_header.dart';

class AboutHowToJoinSection extends StatelessWidget {
  const AboutHowToJoinSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final steps = [
      _JoinStep(
        icon: Icons.mail_outlined,
        title: l10n.joinStep1Title,
        description: l10n.joinStep1Desc,
      ),
      _JoinStep(
        icon: Icons.assignment_outlined,
        title: l10n.joinStep2Title,
        description: l10n.joinStep2Desc,
      ),
      _JoinStep(
        icon: Icons.rocket_launch_outlined,
        title: l10n.joinStep3Title,
        description: l10n.joinStep3Desc,
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AboutSectionHeader(
            title: l10n.aboutHowToJoin,
            icon: Icons.group_add_outlined,
            subtitle:
            'Three simple steps to become part of the Sellio team.',
          ),
          const SizedBox(height: AppSpacing.xl),
          ...steps.asMap().entries.map((entry) {
            return _JoinStepCard(
              index: entry.key,
              step: entry.value,
              isLast: entry.key == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _JoinStepCard extends StatelessWidget {
  final int index;
  final _JoinStep step;
  final bool isLast;

  const _JoinStepCard({
    required this.index,
    required this.step,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Timeline Column ──────────────────────────
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: SellioColors.primaryGradient,
                    borderRadius: AppRadius.smAll,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.smAll,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // ─── Content Card ─────────────────────────────
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceLow,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: scheme.stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, size: 18, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          step.title,
                          style: AppTypography.subtitle.copyWith(
                            color: scheme.title,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    step.description,
                    style: AppTypography.body.copyWith(
                      color: scheme.body,
                      height: 1.6,
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

class _JoinStep {
  final IconData icon;
  final String title;
  final String description;

  const _JoinStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}