/// Sellio Metrics — Filter Bar Widget
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surfaceLow,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: scheme.stroke),
          ),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Week filter
              _buildDropdown(
                context: context,
                scheme: scheme,
                label: l10n.filterAllTime,
                value: provider.weekFilter,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(l10n.filterAllTime),
                  ),
                  ...provider.availableWeeks.asMap().entries.map((entry) {
                    final weekStart = DateTime.parse(entry.value);
                    final label = entry.key == 0
                        ? l10n.filterCurrentSprint
                        : formatWeekHeader(weekStart);
                    return DropdownMenuItem(
                      value: entry.value,
                      child: Text(label),
                    );
                  }),
                ],
                onChanged: (v) => provider.setWeekFilter(v ?? 'all'),
              ),

              // Developer filter
              _buildDropdown(
                context: context,
                scheme: scheme,
                label: l10n.filterDeveloper,
                value: provider.developerFilter,
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(l10n.filterAllTeam),
                  ),
                  ...provider.availableDevelopers.map((dev) {
                    return DropdownMenuItem(value: dev, child: Text(dev));
                  }),
                ],
                onChanged: (v) => provider.setDeveloperFilter(v ?? 'all'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required SellioColorScheme scheme,
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.body,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
          ),
          child: DropdownButton<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            underline: const SizedBox.shrink(),
            dropdownColor: scheme.surfaceLow,
            style: AppTypography.caption.copyWith(color: scheme.title),
            isDense: true,
          ),
        ),
      ],
    );
  }
}
