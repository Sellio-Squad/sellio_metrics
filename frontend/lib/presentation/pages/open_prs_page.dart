/// Sellio Metrics — Open PRs Page
///
/// Lists open pull requests with search.
/// Follows SRP — orchestrates layout, delegates to PrListTile.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/pr_list_tile.dart';

class OpenPrsPage extends StatelessWidget {
  const OpenPrsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final prs = provider.openPrs;
        final scheme = context.colors;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar only — no status filter
              HuxInput(
                hint: l10n.searchPlaceholder,
                onChanged: (value) => provider.setSearchTerm(value),
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Count badge
              Row(
                children: [
                  Text(
                    l10n.sectionOpenPrs,
                    style: AppTypography.title.copyWith(color: scheme.title),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  HuxBadge(
                    label: '${prs.length}',
                    variant: HuxBadgeVariant.primary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // PR List
              Expanded(
                child: prs.isEmpty
                    ? _EmptyState(scheme: scheme, l10n: l10n)
                    : ListView.builder(
                        itemCount: prs.length,
                        itemBuilder: (context, index) =>
                            PrListTile(pr: prs[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final SellioColorScheme scheme;
  final AppLocalizations l10n;

  const _EmptyState({required this.scheme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: scheme.hint,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.searchNoResults,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ],
      ),
    );
  }
}
