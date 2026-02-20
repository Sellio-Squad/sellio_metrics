/// Sellio Metrics — About How to Join Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'about_section_header.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AboutSectionHeader(
          title: l10n.aboutHowToJoin,
          icon: Icons.group_add_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        ...steps.asMap().entries.map((entry) {
          return _JoinStepCard(index: entry.key, step: entry.value);
        }),
      ],
    );
  }
}

class _JoinStepCard extends StatelessWidget {
  final int index;
  final _JoinStep step;

  const _JoinStepCard({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: scheme.surfaceLow,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.stroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: SellioColors.primaryGradient,
                borderRadius: AppRadius.smAll,
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
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, size: 18, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        step.title,
                        style: AppTypography.subtitle
                            .copyWith(color: scheme.title),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
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
          ],
        ),
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
