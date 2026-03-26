import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/gemini_usage_entity.dart';
import 'package:sellio_metrics/presentation/pages/observability/providers/health_status_provider.dart';
import 'package:sellio_metrics/presentation/widgets/common/loading_row.dart';

class GeminiUsageBanner extends StatelessWidget {
  const GeminiUsageBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HealthStatusProvider>();
    final scheme = context.colors;

    if (provider.isLoading) {
      return const LoadingRow(label: 'Checking Gemini quota…');
    }

    final usage = provider.geminiUsage;
    if (usage == null) {
      return Text(
        'Unable to fetch Gemini usage',
        style: AppTypography.caption.copyWith(color: scheme.hint),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ─────────────────────────────────────
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 18, color: _headerColor(scheme, usage)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Gemini AI  ·  ${usage.model}',
              style: AppTypography.caption.copyWith(
                color: scheme.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _StatusChip(usage: usage, scheme: scheme),
          ],
        ),

        // ─── Rate-limited banner ─────────────────────────
        if (usage.isRateLimited) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: scheme.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.timerOff, size: 14, color: scheme.red),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Rate limited — retry in ${usage.retryAfterSeconds}s',
                    style: AppTypography.caption
                        .copyWith(color: scheme.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // ─── Daily requests progress ─────────────────────
        _QuotaRow(
          label: 'Requests today',
          used: usage.requestsToday,
          limit: usage.dailyRequestLimit,
          fraction: usage.dailyUsedFraction,
          scheme: scheme,
        ),

        const SizedBox(height: AppSpacing.sm),

        // ─── Rate cap info ───────────────────────────────
        Row(
          children: [
            Icon(LucideIcons.clock, size: 13, color: scheme.hint),
            const SizedBox(width: 4),
            Text(
              'Rate cap: ${usage.minuteRequestLimit} req/min · ${usage.dailyRequestLimit} req/day',
              style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
            ),
          ],
        ),

        // ─── Errors today ────────────────────────────────
        if (usage.hasErrors) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, size: 13, color: scheme.secondary),
              const SizedBox(width: 4),
              Text(
                '${usage.errorsToday} error${usage.errorsToday == 1 ? '' : 's'} today',
                style: AppTypography.caption.copyWith(
                    color: scheme.secondary, fontWeight: FontWeight.w600, fontSize: 11),
              ),
              if (usage.lastErrorCode != null) ...[
                const SizedBox(width: 4),
                Text(
                  '(HTTP ${usage.lastErrorCode})',
                  style: AppTypography.caption
                      .copyWith(color: scheme.hint, fontSize: 11),
                ),
              ],
            ],
          ),
          if (usage.lastErrorMessage != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 17),
              child: Text(
                usage.lastErrorMessage!,
                style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],

        // ─── Last request time ───────────────────────────
        if (usage.lastRequestAt != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(LucideIcons.history, size: 13, color: scheme.hint),
              const SizedBox(width: 4),
              Text(
                'Last request: ${_formatTime(usage.lastRequestAt!)}',
                style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _headerColor(SellioColorScheme scheme, GeminiUsageEntity usage) {
    if (usage.isRateLimited) return scheme.red;
    if (usage.dailyUsedFraction >= 0.9) return scheme.red;
    if (usage.dailyUsedFraction >= 0.7) return scheme.secondary;
    return scheme.green;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─── Status chip ─────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final GeminiUsageEntity usage;
  final SellioColorScheme scheme;
  const _StatusChip({required this.usage, required this.scheme});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    late IconData icon;

    if (usage.isRateLimited) {
      color = scheme.red;
      label = 'Rate Limited';
      icon = LucideIcons.xCircle;
    } else if (usage.dailyUsedFraction >= 0.9) {
      color = scheme.red;
      label = 'Near Limit';
      icon = LucideIcons.alertOctagon;
    } else if (usage.dailyUsedFraction >= 0.7) {
      color = scheme.secondary;
      label = 'High Usage';
      icon = LucideIcons.alertTriangle;
    } else {
      color = scheme.green;
      label = 'OK';
      icon = LucideIcons.checkCircle2;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Quota progress row ───────────────────────────────────────

class _QuotaRow extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final double fraction;
  final SellioColorScheme scheme;
  const _QuotaRow({
    required this.label,
    required this.used,
    required this.limit,
    required this.fraction,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = fraction >= 0.9
        ? scheme.red
        : fraction >= 0.7
            ? scheme.secondary
            : scheme.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    AppTypography.caption.copyWith(color: scheme.body, fontSize: 12)),
            Text(
              '$used / $limit',
              style: AppTypography.caption.copyWith(
                  color: barColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: scheme.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
