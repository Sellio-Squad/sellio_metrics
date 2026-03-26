import 'package:flutter/material.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/gemini_usage_banner.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/github_rate_limit_banner.dart';
import 'package:sellio_metrics/presentation/pages/setting/widgets/kv_cache_quota_banner.dart';

class ObservabilityPage extends StatelessWidget {
  const ObservabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(l10n.obsTitle, style: context.textTheme.headlineSmall),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.obsSubtitle,
              style: context.textTheme.bodyMedium?.copyWith(color: scheme.hint),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── GitHub & KV Rate Limits ───────────────
            Text(
              l10n.obsRateLimits,
              style: context.textTheme.titleMedium?.copyWith(color: scheme.title),
            ),
            const SizedBox(height: AppSpacing.md),
            const SCard(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GitHubRateLimitBanner(),
                    SizedBox(height: AppSpacing.lg),
                    KvCacheQuotaBanner(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ─── Gemini AI Quota ───────────────────────
            Row(
              children: [
                Icon(LucideIcons.sparkles, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Gemini AI Quota',
                  style: context.textTheme.titleMedium?.copyWith(color: scheme.title),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const SCard(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: GeminiUsageBanner(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
