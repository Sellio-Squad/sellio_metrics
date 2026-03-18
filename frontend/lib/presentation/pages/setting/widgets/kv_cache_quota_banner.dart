import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/observability/providers/health_status_provider.dart';
import '../../../../domain/entities/kv_cache_quota_status.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import '../../../widgets/common/loading_row.dart';

class KvCacheQuotaBanner extends StatelessWidget {
  const KvCacheQuotaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;
    final provider = context.watch<HealthStatusProvider>();

    if (provider.isLoading) {
      return LoadingRow(label: l10n.kvCacheQuotaChecking, size: 14);
    }

    final status = provider.cacheQuota;
    if (status == null) {
      return Text(
        l10n.unableToFetchKvCacheQuota,
        style: AppTypography.caption.copyWith(color: scheme.hint),
      );
    }

    final timeColor = _getTimeColor(scheme, status);
    final keysColor = _getKeysColor(scheme, status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.database, size: 18, color: timeColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.kvCacheQuotaTitle,
              style: AppTypography.caption.copyWith(color: scheme.body),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => provider.fetchAll(),
              child: Icon(LucideIcons.refreshCw, size: 14, color: scheme.hint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Daily write limit info
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceHigh,
            borderRadius: AppRadius.smAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.kvCacheQuotaDailyWriteLimit,
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                  Text(
                    '${status.kvFreeWriteLimit} writes/day (${l10n.freeTier})',
                    style: AppTypography.caption.copyWith(
                      color: scheme.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.kvCacheQuotaMaxWrites,
                    style: AppTypography.caption.copyWith(color: scheme.hint),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.greenSurface,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      '≤ ${status.maxWritesPerRequest}',
                      style: AppTypography.caption.copyWith(
                        color: scheme.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Quota reset countdown bar
        Row(
          children: [
            Icon(LucideIcons.timer, size: 14, color: timeColor),
            const SizedBox(width: 4),
            Text(
              status.resetLabel,
              style: AppTypography.caption.copyWith(color: timeColor),
            ),
            const Spacer(),
            Text(
              l10n.utcMidnight,
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: status.dayFraction.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: scheme.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(timeColor),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Cache hit status
        Row(
          children: [
            Icon(LucideIcons.zap, size: 14, color: keysColor),
            const SizedBox(width: 4),
            Text(
              l10n.kvCacheQuotaKeysCached(status.cachedKeyCount, status.totalKeys),
              style: AppTypography.caption.copyWith(color: keysColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: status.cachedKeys.entries.map((e) {
            final hit = (e.value as Map?)?['hit'] == true;
            final label = e.key.split(':').last;
            return _CacheTag(label: label, hit: hit);
          }).toList(),
        ),
      ],
    );
  }

  Color _getTimeColor(SellioColorScheme scheme, KvCacheQuotaStatus status) {
    if (status.kvSecondsToReset < 3600) return scheme.green;
    if (status.kvSecondsToReset < 10800) return scheme.secondary;
    return scheme.primary;
  }

  Color _getKeysColor(SellioColorScheme scheme, KvCacheQuotaStatus status) {
    if (status.cachedKeyCount == status.totalKeys) return scheme.green;
    if (status.cachedKeyCount > 0) return scheme.secondary;
    return scheme.red;
  }
}

class _CacheTag extends StatelessWidget {
  final String label;
  final bool hit;

  const _CacheTag({required this.label, required this.hit});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final color = hit ? scheme.green : scheme.red;
    final bg = hit ? scheme.greenSubtle : scheme.redSubtle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hit ? LucideIcons.check : LucideIcons.circle,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: hit ? scheme.green : scheme.hint,
            ),
          ),
        ],
      ),
    );
  }
}
