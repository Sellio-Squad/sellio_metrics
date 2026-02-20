/// Sellio Metrics — Team Structure Card Widget
///
/// Displays team cards with team name, leader, and description.
/// Follows SRP — only responsible for rendering team structure.
library;

import 'package:flutter/material.dart';

import '../../core/constants/layout_constants.dart';
import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Pure data class for team display — no framework types.
class TeamInfo {
  final String name;
  final String leader;
  final String description;

  const TeamInfo({
    required this.name,
    required this.leader,
    required this.description,
  });
}

class TeamStructureCard extends StatelessWidget {
  const TeamStructureCard({super.key});

  static const _teamIcons = [
    Icons.build_circle_outlined,
    Icons.phone_android_outlined,
    Icons.dns_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    // Teams are localized
    final teams = [
      TeamInfo(
        name: l10n.teamPlatformName,
        leader: l10n.teamPlatformLeader,
        description: l10n.teamPlatformDesc,
      ),
      TeamInfo(
        name: l10n.teamProductName,
        leader: l10n.teamProductLeader,
        description: l10n.teamProductDesc,
      ),
      TeamInfo(
        name: l10n.teamBackendName,
        leader: l10n.teamBackendLeader,
        description: l10n.teamBackendDesc,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_outlined,
                size: LayoutConstants.iconSizeMd, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.sectionTeamStructure,
              style: AppTypography.title.copyWith(color: scheme.title),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                constraints.maxWidth > LayoutConstants.gridBreakpoint ? 3 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
                mainAxisExtent: 160,
              ),
              itemCount: teams.length,
              itemBuilder: (context, index) =>
                  _TeamCard(team: teams[index], icon: _teamIcons[index]),
            );
          },
        ),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final TeamInfo team;
  final IconData icon;

  const _TeamCard({required this.team, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border(
          top: BorderSide(color: scheme.primary, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primaryVariant,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  team.name,
                  style: AppTypography.subtitle.copyWith(color: scheme.title),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.person, size: LayoutConstants.iconSizeSm,
                  color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${l10n.teamLeader}: ${team.leader}',
                style: AppTypography.caption.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            team.description,
            style: AppTypography.caption.copyWith(color: scheme.hint),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
