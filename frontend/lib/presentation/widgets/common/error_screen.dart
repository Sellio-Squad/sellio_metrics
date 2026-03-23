
import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const ErrorScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: scheme.disabled),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.errorLoadingData,
            style: AppTypography.body.copyWith(color: scheme.body),
          ),
          const SizedBox(height: AppSpacing.lg),
          SButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
