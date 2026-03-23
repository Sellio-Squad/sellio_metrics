import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/observability/providers/health_status_provider.dart';
import 'package:sellio_metrics/domain/entities/github_rate_limit_status.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_row.dart';

class GitHubRateLimitBanner extends StatelessWidget {
  const GitHubRateLimitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final provider = context.watch<HealthStatusProvider>();

    if (provider.isLoading) {
      return LoadingRow(label: l10n.githubRateLimitChecking);
    }

    final status = provider.rateLimit;
    if (status == null) {
      return Text(
        l10n.unableToFetchGitHubRateLimit,
        style: AppTypography.caption.copyWith(color: scheme.hint),
      );
    }

    final barColor = _getBarColor(scheme, status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.gauge, size: 18, color: barColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.githubRateLimitTitle,
              style: AppTypography.caption.copyWith(color: scheme.body),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: status.usedFraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: scheme.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.githubRateLimitRemaining(status.remaining, status.limit),
              style: AppTypography.caption.copyWith(color: scheme.body),
            ),
            Text(
              status.resetLabel,
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ],
        ),
      ],
    );
  }

  Color _getBarColor(SellioColorScheme scheme, GitHubRateLimitStatus status) {
    if (status.remaining <= (status.limit * 0.1)) return scheme.red;
    if (status.remaining <= (status.limit * 0.3)) return scheme.secondary;
    return scheme.green;
  }
}
