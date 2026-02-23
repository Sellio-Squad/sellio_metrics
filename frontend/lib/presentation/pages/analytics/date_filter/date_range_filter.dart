library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/layout_constants.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../design_system/components/s_button.dart';
import '../../../../design_system/components/s_date_picker.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../providers/dashboard_provider.dart';
import 'date_range_chip.dart';

class DateRangeFilter extends StatelessWidget {
  const DateRangeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final now = DateTime.now();
    final firstDate = DateTime(2024);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Start date
          SizedBox(
            width: 180,
            child: SDatePicker(
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
            child: SDatePicker(
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
            DateRangeChip(
              start: provider.startDate,
              end: provider.endDate,
            ),

          // Current Sprint shortcut
          SButton(
            variant: SButtonVariant.ghost,
            size: SButtonSize.small,
            onPressed: () {
              final sprintEnd = now;
              final sprintStart = now.subtract(
                const Duration(days: LayoutConstants.sprintDurationDays),
              );
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
            SButton(
              variant: SButtonVariant.ghost,
              size: SButtonSize.small,
              onPressed: () => provider.setDateRange(null, null),
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
}
