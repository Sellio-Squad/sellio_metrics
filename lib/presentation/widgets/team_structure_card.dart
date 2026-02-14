/// Sellio Metrics — Team Structure Card Widget
///
/// Displays team cards with team name, leader, and description.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Team data model for display.
class TeamInfo {
  final String name;
  final String leader;
  final String description;
  final IconData icon;
  final Color color;

  const TeamInfo({
    required this.name,
    required this.leader,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class TeamStructureCard extends StatelessWidget {
  const TeamStructureCard({super.key});

  // Placeholder data — update with actual team info
  static const _teams = [
    TeamInfo(
      name: 'Platform Team',
      leader: 'Team Lead 1',
      description: 'Core infrastructure, CI/CD, developer tools',
      icon: Icons.build_circle_outlined,
      color: SellioColors.primaryIndigo,
    ),
    TeamInfo(
      name: 'Product Team',
      leader: 'Team Lead 2',
      description: 'Customer-facing features, UI/UX, mobile apps',
      icon: Icons.phone_android_outlined,
      color: SellioColors.success,
    ),
    TeamInfo(
      name: 'Backend Team',
      leader: 'Team Lead 3',
      description: 'APIs, microservices, data pipelines',
      icon: Icons.dns_outlined,
      color: SellioColors.warning,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏗️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.sectionTeamStructure,
              style: AppTypography.title.copyWith(
                color: context.isDark ? Colors.white : SellioColors.gray700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.lg,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: _teams
                  .map((team) => _buildTeamCard(context, team, l10n))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeamCard(
    BuildContext context,
    TeamInfo team,
    AppLocalizations l10n,
  ) {
    return HuxCard(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.isDark
              ? SellioColors.darkSurface
              : SellioColors.lightSurface,
          borderRadius: AppRadius.lgAll,
          border: Border(
            top: BorderSide(color: team.color, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: team.color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(team.icon, color: team.color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    team.name,
                    style: AppTypography.subtitle.copyWith(
                      color: context.isDark
                          ? Colors.white
                          : SellioColors.gray700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: team.color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${l10n.teamLeader}: ${team.leader}',
                  style: AppTypography.caption.copyWith(
                    color: team.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              team.description,
              style: AppTypography.caption.copyWith(
                color: context.isDark
                    ? Colors.white54
                    : SellioColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
