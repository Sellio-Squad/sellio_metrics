import 'package:flutter/material.dart';

import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final SellioColorScheme scheme;
  final AppLocalizations l10n;

  const EmptyState({super.key, required this.scheme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: scheme.hint),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.searchNoResults,
            style: AppTypography.body.copyWith(color: scheme.hint),
          ),
        ],
      ),
    );
  }
}
