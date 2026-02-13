/// Sellio Metrics — Error Screen Component
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';

import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

class ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const ErrorScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.isDark
          ? SellioColors.darkBackground
          : SellioColors.lightBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.isDark ? Colors.white24 : SellioColors.gray300,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              l10n.errorLoadingData,
              style: AppTypography.body.copyWith(
                color: context.isDark
                    ? Colors.white54
                    : SellioColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            HuxButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
