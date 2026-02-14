/// Sellio Metrics — Date Range Filter
///
/// Date range selection with validation and current sprint auto-select.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart' hide DateFormat;
import 'package:intl/intl.dart';
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
    final now = DateTime.now();
    final firstDate = DateTime(2024);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.isDark
            ? SellioColors.darkSurface
            : SellioColors.lightSurface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: context.isDark ? Colors.white10 : SellioColors.gray300,
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Start date
          SizedBox(
            width: 180,
            child: HuxDatePicker(
              placeholder: l10n.filterStartDate,
              initialDate: provider.startDate,
              firstDate: firstDate,
              lastDate: provider.endDate ?? now,
              onDateChanged: (date) {
                provider.setDateRange(date, provider.endDate);
              },
            ),
          ),

          // End date — firstDate constrained to startDate
          SizedBox(
            width: 180,
            child: HuxDatePicker(
              placeholder: l10n.filterEndDate,
              initialDate: provider.endDate,
              firstDate: provider.startDate ?? firstDate,
              lastDate: now,
              onDateChanged: (date) {
                provider.setDateRange(provider.startDate, date);
              },
            ),
          ),

          // Selected date display
          if (provider.startDate != null || provider.endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: SellioColors.primaryIndigo.withAlpha(15),
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: SellioColors.primaryIndigo.withAlpha(40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range,
                    size: 14,
                    color: SellioColors.primaryIndigo,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _formatDateRange(
                      provider.startDate,
                      provider.endDate,
                      dateFormat,
                    ),
                    style: AppTypography.caption.copyWith(
                      color: SellioColors.primaryIndigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Current Sprint shortcut
          HuxButton(
            variant: HuxButtonVariant.ghost,
            size: HuxButtonSize.small,
            onPressed: () {
              final sprintEnd = now;
              final sprintStart = now.subtract(const Duration(days: 14));
              provider.setDateRange(sprintStart, sprintEnd);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.filterCurrentSprint),
              ],
            ),
          ),

          // Clear filters
          if (provider.startDate != null || provider.endDate != null)
            HuxButton(
              variant: HuxButtonVariant.ghost,
              size: HuxButtonSize.small,
              onPressed: () {
                provider.setDateRange(null, null);
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
      ),
    );
  }

  String _formatDateRange(
    DateTime? start,
    DateTime? end,
    DateFormat format,
  ) {
    if (start != null && end != null) {
      return '${format.format(start)} → ${format.format(end)}';
    } else if (start != null) {
      return 'From ${format.format(start)}';
    } else if (end != null) {
      return 'Until ${format.format(end)}';
    }
    return '';
  }
}
