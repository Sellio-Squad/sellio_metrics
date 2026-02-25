/// Sellio Metrics — About Tech Stack Section
library;

import 'package:flutter/material.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../design_system/design_system.dart';
import '../../../core/l10n/app_localizations.dart';
import 'about_section_header.dart';

class AboutTechStackSection extends StatelessWidget {
  const AboutTechStackSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final techItems = [
      _TechItem(l10n.techFlutter, l10n.techFlutterRole, LucideIcons.smartphone),
      _TechItem(l10n.techKotlin, l10n.techKotlinRole, LucideIcons.server),
      _TechItem(l10n.techGithubActions, l10n.techGithubActionsRole, LucideIcons.gitBranch),
      _TechItem(l10n.techFirebase, l10n.techFirebaseRole, LucideIcons.database),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AboutSectionHeader(title: l10n.aboutTechStack, icon: Icons.code),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: techItems.map((tech) => _TechCard(tech: tech)).toList(),
        ),
      ],
    );
  }
}

class _TechCard extends StatelessWidget {
  final _TechItem tech;

  const _TechCard({required this.tech});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Row(
        children: [
          Icon(tech.icon, color: scheme.primary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tech.name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                ),
                Text(
                  tech.role,
                  style: AppTypography.overline.copyWith(color: scheme.hint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechItem {
  final String name;
  final String role;
  final IconData icon;

  const _TechItem(this.name, this.role, this.icon);
}
