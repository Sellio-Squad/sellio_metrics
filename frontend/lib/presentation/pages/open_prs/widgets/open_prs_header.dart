
import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class OpenPrsHeader extends StatelessWidget {
  final int prCount;
  final ValueChanged<String> onSearchChanged;

  const OpenPrsHeader({
    super.key,
    required this.prCount,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar — full width
        SInput(
          hint: l10n.searchPlaceholder,
          onChanged: onSearchChanged,
          prefixIcon: const Icon(Icons.search),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Title + count badge
        Row(
          children: [
            Text(
              l10n.sectionOpenPrs,
              style: AppTypography.title.copyWith(color: scheme.title),
            ),
            const SizedBox(width: AppSpacing.sm),
            SBadge(
              label: '$prCount',
              variant: SBadgeVariant.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
