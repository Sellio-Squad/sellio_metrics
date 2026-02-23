import 'package:flutter/material.dart';

import '../../../../core/constants/layout_constants.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/app_localizations.dart';

class DateRangeChip extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;

  const DateRangeChip({super.key, this.start, this.end});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    String text;
    if (start != null && end != null) {
      text = '${formatFullDate(start!)} → ${formatFullDate(end!)}';
    } else if (start != null) {
      text = '${l10n.filterFrom} ${formatFullDate(start!)}';
    } else if (end != null) {
      text = '${l10n.filterUntil} ${formatFullDate(end!)}';
    } else {
      text = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryVariant,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.date_range,
            size: LayoutConstants.iconSizeSm,
            color: scheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
