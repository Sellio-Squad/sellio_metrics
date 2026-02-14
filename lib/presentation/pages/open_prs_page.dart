/// Sellio Metrics — Open PRs Page
///
/// Lists open pull requests with search.
/// Uses domain entities, localized strings, and theme extension.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
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
                    style: AppTypography.title.copyWith(
                      color: context.isDark
                          ? Colors.white
                          : SellioColors.gray700,
                    ),
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
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: context.isDark
                                  ? Colors.white24
                                  : SellioColors.gray300,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l10n.searchNoResults,
                              style: AppTypography.body.copyWith(
                                color: context.isDark
                                    ? Colors.white38
                                    : SellioColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
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
