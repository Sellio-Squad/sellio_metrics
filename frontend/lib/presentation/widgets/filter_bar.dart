/// Sellio Metrics — Filter Bar Widget
library;

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../l10n/app_strings.dart';
import '../providers/dashboard_provider.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2E2E3E)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Week filter
              _buildDropdown(
                context: context,
                label: AppStrings.filterByWeek,
                value: provider.weekFilter,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text(AppStrings.filterAllTime),
                  ),
                  ...provider.availableWeeks.asMap().entries.map((entry) {
                    final weekStart = DateTime.parse(entry.value);
                    final label = entry.key == 0
                        ? AppStrings.filterCurrentWeek
                        : formatWeekHeader(weekStart);
                    return DropdownMenuItem(
                      value: entry.value,
                      child: Text(label),
                    );
                  }),
                ],
                onChanged: (v) => provider.setWeekFilter(v ?? 'all'),
                isDark: isDark,
              ),

              // Developer filter
              _buildDropdown(
                context: context,
                label: AppStrings.filterViewAs,
                value: provider.developerFilter,
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text(AppStrings.filterAllTeam),
                  ),
                  ...provider.availableDevelopers.map((dev) {
                    return DropdownMenuItem(value: dev, child: Text(dev));
                  }),
                ],
                onChanged: (v) => provider.setDeveloperFilter(v ?? 'all'),
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF3F4F6),
            borderRadius: AppRadius.mdAll,
          ),
          child: DropdownButton<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            dropdownColor:
                isDark ? const Color(0xFF2A2A3E) : Colors.white,
            style: AppTypography.caption.copyWith(
              color: isDark ? Colors.white : const Color(0xFF1a1a2e),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
