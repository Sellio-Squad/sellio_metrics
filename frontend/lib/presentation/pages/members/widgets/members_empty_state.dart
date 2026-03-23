import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class MembersEmptyState extends StatelessWidget {
  const MembersEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: scheme.disabled,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.emptyData,
            style: AppTypography.body.copyWith(
              color: scheme.hint,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
