/// Sellio Metrics — Date Range Filter
///
/// Replaces the old FilterBar with HuxDatePicker for date selection
/// and a developer dropdown filter.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/dashboard_provider.dart';

class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final l10n = AppLocalizations.of(context);
    final devs = provider.availableDevelopers;
    final now = DateTime.now();
    final firstDate = DateTime(2024);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      alignment: WrapAlignment.start,
      children: [
        // Start date
        SizedBox(
          width: 180,
          child: HuxDatePicker(
            placeholder: l10n.filterStartDate,
            initialDate: provider.startDate,
            firstDate: firstDate,
            lastDate: now,
            onDateChanged: (date) {
              provider.setDateRange(date, provider.endDate);
            },
          ),
        ),

        // End date
        SizedBox(
          width: 180,
          child: HuxDatePicker(
            placeholder: l10n.filterEndDate,
            initialDate: provider.endDate,
            firstDate: firstDate,
            lastDate: now,
            onDateChanged: (date) {
              provider.setDateRange(provider.startDate, date);
            },
          ),
        ),

        // Developer filter
        SizedBox(
          width: 200,
          child: _buildDeveloperDropdown(
            context,
            provider,
            devs,
            l10n,
          ),
        ),

        // Clear filters
        if (provider.startDate != null ||
            provider.endDate != null ||
            provider.developerFilter != 'all')
          HuxButton(
            variant: HuxButtonVariant.ghost,
            size: HuxButtonSize.small,
            onPressed: () {
              provider.setDateRange(null, null);
              provider.setDeveloperFilter('all');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.clear, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.filterAllTime),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDeveloperDropdown(
    BuildContext context,
    DashboardProvider provider,
    List<String> devs,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.isDark
            ? SellioColors.darkSurface
            : SellioColors.lightSurface,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
        ),
      ),
      child: DropdownButton<String>(
        value: provider.developerFilter,
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.expand_more, size: 18),
        dropdownColor: context.isDark
            ? SellioColors.darkSurface
            : SellioColors.lightSurface,
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              l10n.filterAllTeam,
              style: AppTypography.caption,
            ),
          ),
          ...devs.map(
            (dev) => DropdownMenuItem(
              value: dev,
              child: Text(
                dev,
                style: AppTypography.caption,
              ),
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) provider.setDeveloperFilter(value);
        },
      ),
    );
  }
}
