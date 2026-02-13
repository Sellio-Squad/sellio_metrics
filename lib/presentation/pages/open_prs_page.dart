/// Sellio Metrics — Open PRs Page
///
/// Lists open pull requests with search and status filtering.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/pr_list_tile.dart';

class OpenPrsPage extends StatelessWidget {
  const OpenPrsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final prs = provider.openPrs;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              Row(
                children: [
                  Expanded(
                    child: HuxInput(
                      hint: AppStrings.searchPlaceholder,
                      onChanged: (value) => provider.setSearchTerm(value),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A3E)
                          : const Color(0xFFF3F4F6),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: DropdownButton<String>(
                      value: provider.statusFilter,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All Status'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'approved',
                          child: Text('Approved'),
                        ),
                      ],
                      onChanged: (v) =>
                          provider.setStatusFilter(v ?? 'all'),
                      underline: const SizedBox.shrink(),
                      dropdownColor:
                          isDark ? const Color(0xFF2A2A3E) : Colors.white,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1a1a2e),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Count badge
              Row(
                children: [
                  Text(
                    AppStrings.sectionOpenPrs,
                    style: AppTypography.title.copyWith(
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1a1a2e),
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
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFD1D5DB),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              AppStrings.searchNoResults,
                              style: AppTypography.body.copyWith(
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF9CA3AF),
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
