/// Sellio Metrics — Observability Page (v2 — Advanced)
///
/// Premium observability dashboard with:
/// - Stats KPIs (total, latency, error rate, uptime, calls/min)
/// - Rate Limits section (GitHub API quota)
/// - Latency Distribution (percentile bars per source)
/// - Abuse / Spike Detection alerts
/// - Service Dependency Graph
/// - Source Breakdown chart
/// - Slowest Endpoints table
/// - Recent Errors feed
/// - Live API Call Feed with pagination
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../design_system/design_system.dart';
import '../../../domain/entities/api_call_entity.dart';
import '../../providers/observability_provider.dart';

class ObservabilityPage extends StatefulWidget {
  const ObservabilityPage({super.key});

  @override
  State<ObservabilityPage> createState() => _ObservabilityPageState();
}

class _ObservabilityPageState extends State<ObservabilityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ObservabilityProvider>().startMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ObservabilityProvider>(
      builder: (context, provider, _) {
        if (provider.status == ObservabilityStatus.loading &&
            provider.stats.isEmpty) {
          return Center(child: SLoading());
        }

        if (provider.status == ObservabilityStatus.error &&
            provider.stats.isEmpty) {
          return _ErrorView(message: provider.errorMessage ?? 'Unknown error',
              onRetry: provider.loadData);
        }

        return RefreshIndicator(
          onRefresh: provider.loadData,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _PageHeader(provider: provider),
              const SizedBox(height: AppSpacing.lg),
              _StatsSummaryRow(stats: provider.stats),
              const SizedBox(height: AppSpacing.lg),

              // Rate Limits
              if (provider.stats.rateLimits.isNotEmpty) ...[
                _RateLimitsSection(rateLimits: provider.stats.rateLimits),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Cache Status
              _CacheStatsSection(cacheStats: provider.stats.cacheStats),
              const SizedBox(height: AppSpacing.lg),

              // Abuse / Spike Detection
              _AbuseSection(abuse: provider.stats.abuse),
              const SizedBox(height: AppSpacing.lg),

              // Latency Distribution
              _LatencyDistributionSection(
                overall: provider.stats.latency,
                bySource: provider.stats.latencyBySource,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Dependency Graph
              if (provider.stats.dependencyGraph.edges.isNotEmpty) ...[
                _DependencyGraphSection(graph: provider.stats.dependencyGraph),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Source Breakdown
              _SourceFilterBar(
                selectedSource: provider.sourceFilter,
                sources: provider.stats.callsBySource,
                onSourceSelected: provider.setSourceFilter,
              ),
              const SizedBox(height: AppSpacing.md),
              _SourceBreakdownSection(breakdowns: provider.stats.callsBySource),
              const SizedBox(height: AppSpacing.lg),

              // Slowest Endpoints
              _SlowestEndpointsSection(endpoints: provider.stats.slowestEndpoints),
              const SizedBox(height: AppSpacing.lg),

              // Recent Errors
              if (provider.stats.recentErrors.isNotEmpty) ...[
                _RecentErrorsSection(errors: provider.stats.recentErrors),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Live Feed
              _LiveCallFeed(
                calls: provider.recentCalls,
                hasMore: provider.hasMoreCalls,
                isLoadingMore: provider.isLoadingMore,
                onLoadMore: provider.loadMore,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Error View ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.alertTriangle, size: 48, color: SellioColors.red),
          const SizedBox(height: AppSpacing.md),
          Text('Failed to load observability data',
              style: AppTypography.subtitle.copyWith(color: scheme.title)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppTypography.caption.copyWith(color: scheme.hint),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SButton(child: Text('Retry'), onPressed: onRetry),
        ],
      ),
    );
  }
}

// ─── Page Header ────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final ObservabilityProvider provider;

  const _PageHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Icon(LucideIcons.activity, color: scheme.primary, size: 28),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.obsTitle,
                  style: AppTypography.title.copyWith(color: scheme.title)),
              Text(l10n.obsSubtitle,
                  style: AppTypography.caption.copyWith(color: scheme.hint)),
            ],
          ),
        ),
        if (provider.stats.abuse.isSpiking)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: SellioColors.red.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertTriangle, size: 14, color: SellioColors.red),
                const SizedBox(width: AppSpacing.xs),
                Text('SPIKE', style: AppTypography.caption.copyWith(
                    color: SellioColors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        const SizedBox(width: AppSpacing.sm),
        if (provider.isPolling)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: SellioColors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(
                    color: SellioColors.green, shape: BoxShape.circle)),
                const SizedBox(width: AppSpacing.xs),
                Text(l10n.obsLive, style: AppTypography.caption.copyWith(
                    color: SellioColors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Stats Summary Row ──────────────────────────────────────

class _StatsSummaryRow extends StatelessWidget {
  final ObservabilityStatsEntity stats;
  const _StatsSummaryRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    final items = [
      _StatItem(icon: LucideIcons.barChart3, label: l10n.obsTotalCalls,
          value: stats.totalCalls.toString(), color: scheme.primary),
      _StatItem(icon: LucideIcons.clock, label: l10n.obsAvgLatency,
          value: '${stats.latency.avg.toStringAsFixed(1)}ms', color: SellioColors.blue),
      _StatItem(icon: LucideIcons.zap, label: l10n.obsP95Latency,
          value: '${stats.latency.p95.toStringAsFixed(1)}ms', color: SellioColors.amber),
      _StatItem(icon: LucideIcons.alertTriangle, label: l10n.obsErrorRate,
          value: '${stats.errorPercent.toStringAsFixed(2)}%',
          color: stats.errorPercent > 5 ? SellioColors.red : SellioColors.green),
      _StatItem(icon: LucideIcons.timer, label: l10n.obsUptime,
          value: stats.formattedUptime, color: SellioColors.green),
      _StatItem(icon: LucideIcons.gauge, label: l10n.obsCallsPerMin,
          value: stats.abuse.callsPerMinute.toString(),
          color: stats.abuse.isSpiking ? SellioColors.red : SellioColors.blue,
          subtitle: stats.abuse.trendLabel),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000 ? 6
            : constraints.maxWidth > 700 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md, crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 2.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => items[i],
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const _StatItem({
    required this.icon, required this.label,
    required this.value, required this.color, this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(label, style: AppTypography.caption.copyWith(color: scheme.hint),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Row(children: [
              Text(value, style: AppTypography.heading.copyWith(
                  color: scheme.title, fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(subtitle!, style: AppTypography.caption.copyWith(
                    color: subtitle!.startsWith('+') ? SellioColors.red
                        : subtitle!.startsWith('-') ? SellioColors.green : scheme.hint,
                    fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Rate Limits Section ────────────────────────────────────

class _RateLimitsSection extends StatelessWidget {
  final List<RateLimitEntity> rateLimits;
  const _RateLimitsSection({required this.rateLimits});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.shield, size: 18, color: SellioColors.amber),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsRateLimits, style: AppTypography.subtitle.copyWith(color: scheme.title)),
            ]),
            const SizedBox(height: AppSpacing.md),
            ...rateLimits.map((rl) {
              final pctUsed = rl.percentUsed;
              final isWarning = pctUsed > 0.8;
              final isDanger = pctUsed > 0.95;
              final barColor = isDanger ? SellioColors.red
                  : isWarning ? SellioColors.amber : SellioColors.green;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_capitalizeSource(rl.source),
                          style: AppTypography.body.copyWith(color: scheme.title, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${rl.remaining}/${rl.limit} remaining',
                          style: AppTypography.caption.copyWith(color: scheme.hint)),
                    ]),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: LinearProgressIndicator(
                        value: pctUsed.clamp(0.0, 1.0),
                        backgroundColor: scheme.stroke,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Resets at ${_formatTime(rl.resetAt)}',
                        style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _capitalizeSource(String s) => s[0].toUpperCase() + s.substring(1);

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Cache Stats Section ────────────────────────────────────

class _CacheStatsSection extends StatelessWidget {
  final CacheStatsEntity cacheStats;
  const _CacheStatsSection({required this.cacheStats});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isConnected = cacheStats.connected;
    final statusColor = isConnected ? SellioColors.green : SellioColors.amber;
    final statusLabel = isConnected ? 'Connected' : 'Disconnected';
    final statusIcon = isConnected ? LucideIcons.checkCircle : LucideIcons.alertCircle;

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              const Icon(LucideIcons.database, size: 18, color: SellioColors.blue),
              const SizedBox(width: AppSpacing.sm),
              Text('Redis Cache', style: AppTypography.subtitle.copyWith(color: scheme.title)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: statusColor.withAlpha(60)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: AppSpacing.xs),
                  Text(statusLabel, style: AppTypography.caption.copyWith(
                      color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),

            // Stats grid
            Row(children: [
              Expanded(child: _CacheMiniStat(
                label: 'Hits', value: '${cacheStats.hits}',
                color: SellioColors.green, scheme: scheme)),
              Expanded(child: _CacheMiniStat(
                label: 'Misses', value: '${cacheStats.misses}',
                color: SellioColors.amber, scheme: scheme)),
              Expanded(child: _CacheMiniStat(
                label: 'Writes', value: '${cacheStats.sets}',
                color: SellioColors.blue, scheme: scheme)),
              Expanded(child: _CacheMiniStat(
                label: 'Keys', value: '${cacheStats.keyCount}',
                color: SellioColors.purple, scheme: scheme)),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Hit Rate Bar
            Row(children: [
              Text('Hit Rate', style: AppTypography.caption.copyWith(
                  color: scheme.hint, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${cacheStats.hitPercent.toStringAsFixed(1)}%',
                  style: AppTypography.caption.copyWith(
                      color: cacheStats.hitPercent > 70 ? SellioColors.green
                          : cacheStats.hitPercent > 40 ? SellioColors.amber
                          : SellioColors.red,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: LinearProgressIndicator(
                value: (cacheStats.hitRate).clamp(0.0, 1.0),
                backgroundColor: scheme.stroke,
                valueColor: AlwaysStoppedAnimation<Color>(
                  cacheStats.hitPercent > 70 ? SellioColors.green
                      : cacheStats.hitPercent > 40 ? SellioColors.amber
                      : SellioColors.red,
                ),
                minHeight: 8,
              ),
            ),

            // Errors
            if (cacheStats.errors > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Icon(LucideIcons.alertTriangle, size: 14, color: SellioColors.red),
                const SizedBox(width: AppSpacing.xs),
                Text('${cacheStats.errors} cache errors',
                    style: AppTypography.caption.copyWith(color: SellioColors.red)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _CacheMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final dynamic scheme;
  const _CacheMiniStat({required this.label, required this.value,
      required this.color, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: AppTypography.heading.copyWith(
          color: color, fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 2),
      Text(label, style: AppTypography.caption.copyWith(
          color: scheme.hint, fontSize: 10)),
    ]);
  }
}

// ─── Abuse / Spike Detection ────────────────────────────────

class _AbuseSection extends StatelessWidget {
  final AbuseMetricsEntity abuse;
  const _AbuseSection({required this.abuse});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(abuse.isSpiking ? LucideIcons.alertTriangle : LucideIcons.trendingUp,
                  size: 18, color: abuse.isSpiking ? SellioColors.red : scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsTrafficAnalysis, style: AppTypography.subtitle.copyWith(color: scheme.title)),
              if (abuse.isSpiking) ...[
                const SizedBox(width: AppSpacing.sm),
                SBadge(label: l10n.obsSpike, variant: SBadgeVariant.error),
              ],
            ]),
            const SizedBox(height: AppSpacing.md),
            // Metrics row
            Row(children: [
              Expanded(child: _MiniStat(label: l10n.obsCurrentRate,
                  value: '${abuse.callsPerMinute}/min', scheme: scheme)),
              Expanded(child: _MiniStat(label: l10n.obsPreviousRate,
                  value: '${abuse.prevCallsPerMinute}/min', scheme: scheme)),
              Expanded(child: _MiniStat(label: l10n.obsTrailingAvg,
                  value: '${abuse.trailingAvg5Min}/min', scheme: scheme)),
              Expanded(child: _MiniStat(label: l10n.obsPeakRate,
                  value: '${abuse.peakCallsPerMinute}/min', scheme: scheme)),
            ]),
            if (abuse.hotEndpoints.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.obsHotEndpoints,
                  style: AppTypography.caption.copyWith(color: scheme.hint, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              ...abuse.hotEndpoints.map((ep) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(children: [
                  SBadge(label: ep.method, variant: ep.method == 'GET'
                      ? SBadgeVariant.success : SBadgeVariant.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(ep.path, style: AppTypography.caption.copyWith(
                      color: scheme.body, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
                  Text('${ep.callsPerMinute}/min', style: AppTypography.caption.copyWith(
                      color: SellioColors.amber, fontWeight: FontWeight.w600)),
                ]),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final dynamic scheme;
  const _MiniStat({required this.label, required this.value, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTypography.heading.copyWith(
            color: scheme.title, fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 10)),
      ],
    );
  }
}

// ─── Latency Distribution ───────────────────────────────────

class _LatencyDistributionSection extends StatelessWidget {
  final LatencyPercentilesEntity overall;
  final List<LatencyBySourceEntity> bySource;
  const _LatencyDistributionSection({required this.overall, required this.bySource});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.barChart3, size: 18, color: SellioColors.purple),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsLatencyDistribution, style: AppTypography.subtitle.copyWith(color: scheme.title)),
            ]),
            const SizedBox(height: AppSpacing.lg),
            // Overall percentile bars
            _PercentileBar(label: 'P50', value: overall.p50, maxValue: overall.p99, color: SellioColors.green, scheme: scheme),
            _PercentileBar(label: 'P75', value: overall.p75, maxValue: overall.p99, color: SellioColors.blue, scheme: scheme),
            _PercentileBar(label: 'P90', value: overall.p90, maxValue: overall.p99, color: SellioColors.amber, scheme: scheme),
            _PercentileBar(label: 'P95', value: overall.p95, maxValue: overall.p99, color: SellioColors.amber, scheme: scheme),
            _PercentileBar(label: 'P99', value: overall.p99, maxValue: overall.p99, color: SellioColors.red, scheme: scheme),
            const SizedBox(height: AppSpacing.md),
            // Per-source breakdown
            if (bySource.isNotEmpty) ...[
              Text(l10n.obsLatencyBySource, style: AppTypography.caption.copyWith(
                  color: scheme.hint, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              ...bySource.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(_capitalizeSource(s.source),
                      style: AppTypography.caption.copyWith(color: _sourceColor(s.source), fontWeight: FontWeight.w600))),
                  Expanded(child: Text(
                      'avg ${s.percentiles.avg.toStringAsFixed(1)}ms  •  p95 ${s.percentiles.p95.toStringAsFixed(1)}ms  •  max ${s.percentiles.max.toStringAsFixed(0)}ms',
                      style: AppTypography.caption.copyWith(color: scheme.body, fontSize: 11))),
                  Text('${s.callCount}x', style: AppTypography.caption.copyWith(color: scheme.hint)),
                ]),
              )),
            ],
          ],
        ),
      ),
    );
  }

  String _capitalizeSource(String s) => s[0].toUpperCase() + s.substring(1);
  Color _sourceColor(String source) {
    switch (source) {
      case 'internal': return SellioColors.blue;
      case 'github': return SellioColors.purple;
      case 'google': return SellioColors.green;
      default: return SellioColors.amber;
    }
  }
}

class _PercentileBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final dynamic scheme;
  const _PercentileBar({required this.label, required this.value,
    required this.maxValue, required this.color, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        SizedBox(width: 32, child: Text(label, style: AppTypography.caption.copyWith(
            color: scheme.hint, fontWeight: FontWeight.w600, fontSize: 11))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: ratio, backgroundColor: scheme.stroke,
            valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6),
        )),
        SizedBox(width: 65, child: Text('${value.toStringAsFixed(1)}ms',
            style: AppTypography.caption.copyWith(color: scheme.body, fontSize: 11),
            textAlign: TextAlign.right)),
      ]),
    );
  }
}

// ─── Dependency Graph ───────────────────────────────────────

class _DependencyGraphSection extends StatelessWidget {
  final DependencyGraphEntity graph;
  const _DependencyGraphSection({required this.graph});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.network, size: 18, color: SellioColors.purple),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsDependencyGraph, style: AppTypography.subtitle.copyWith(color: scheme.title)),
            ]),
            const SizedBox(height: AppSpacing.lg),
            // Render edges as a visual flow
            ...graph.edges.map((edge) {
              final fromNode = graph.nodes.firstWhere((n) => n.id == edge.from,
                  orElse: () => DependencyNodeEntity(id: edge.from, label: edge.from, type: 'service'));
              final toNode = graph.nodes.firstWhere((n) => n.id == edge.to,
                  orElse: () => DependencyNodeEntity(id: edge.to, label: edge.to, type: 'api'));

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(children: [
                  // From node
                  _NodeChip(label: fromNode.label, type: fromNode.type, scheme: scheme),
                  const SizedBox(width: AppSpacing.sm),
                  // Edge arrow with stats
                  Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(color: edge.hasErrors ? SellioColors.red.withAlpha(60) : scheme.stroke),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: edge.hasErrors ? SellioColors.red.withAlpha(8) : scheme.surface,
                    ),
                    child: Row(children: [
                      Icon(LucideIcons.arrowRight, size: 14, color: scheme.hint),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(
                        '${edge.callCount}x  •  ~${edge.avgDurationMs.toStringAsFixed(0)}ms${edge.hasErrors ? '  •  ${edge.errorCount} err' : ''}',
                        style: AppTypography.caption.copyWith(color: scheme.body, fontSize: 11),
                        overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
                  const SizedBox(width: AppSpacing.sm),
                  // To node
                  _NodeChip(label: toNode.label, type: toNode.type, scheme: scheme),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  final String label;
  final String type;
  final dynamic scheme;
  const _NodeChip({required this.label, required this.type, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final color = type == 'api' ? SellioColors.purple : SellioColors.blue;
    final icon = type == 'api' ? LucideIcons.cloud : LucideIcons.server;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.caption.copyWith(
            color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }
}

// ─── Source Filter Bar ──────────────────────────────────────

class _SourceFilterBar extends StatelessWidget {
  final String? selectedSource;
  final List<SourceBreakdownEntity> sources;
  final ValueChanged<String?> onSourceSelected;
  const _SourceFilterBar({required this.selectedSource, required this.sources, required this.onSourceSelected});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final allSources = ['all', ...sources.map((s) => s.source)];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allSources.map((source) {
          final isSelected = source == 'all' ? selectedSource == null : source == selectedSource;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onSourceSelected(source == 'all' ? null : source),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? scheme.primary : scheme.surfaceLow,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: isSelected ? scheme.primary : scheme.stroke),
                ),
                child: Text(
                  source == 'all' ? l10n.obsAllSources : _sourceLabel(source, l10n),
                  style: AppTypography.caption.copyWith(
                    color: isSelected ? scheme.onPrimary : scheme.body,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sourceLabel(String source, AppLocalizations l10n) {
    switch (source) {
      case 'internal': return l10n.obsSourceInternal;
      case 'github': return l10n.obsSourceGithub;
      case 'google': return l10n.obsSourceGoogle;
      case 'cache': return 'Cache';
      default: return l10n.obsSourceExternal;
    }
  }
}

// ─── Source Breakdown Section ────────────────────────────────

class _SourceBreakdownSection extends StatelessWidget {
  final List<SourceBreakdownEntity> breakdowns;
  const _SourceBreakdownSection({required this.breakdowns});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    if (breakdowns.isEmpty) return const SizedBox.shrink();

    final total = breakdowns.fold<int>(0, (sum, b) => sum + b.count);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.obsSourceBreakdown, style: AppTypography.subtitle.copyWith(color: scheme.title)),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(height: 12, child: Row(
                children: breakdowns.map((b) {
                  final ratio = total > 0 ? b.count / total : 0.0;
                  return Expanded(flex: (ratio * 1000).round().clamp(1, 1000),
                      child: Container(color: _sourceColor(b.source)));
                }).toList(),
              )),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm,
              children: breakdowns.map((b) {
                final pct = total > 0 ? (b.count / total * 100).toStringAsFixed(1) : '0';
                return Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: _sourceColor(b.source), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${_cap(b.source)}: ${b.count} ($pct%) ',
                      style: AppTypography.caption.copyWith(color: scheme.body)),
                  Text('err ${(b.errorRate * 100).toStringAsFixed(1)}%',
                      style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
                ]);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _sourceColor(String s) {
    switch (s) { case 'internal': return SellioColors.blue; case 'github': return SellioColors.purple;
      case 'google': return SellioColors.green; default: return SellioColors.amber; }
  }
  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

// ─── Slowest Endpoints ──────────────────────────────────────

class _SlowestEndpointsSection extends StatelessWidget {
  final List<SlowEndpointEntity> endpoints;
  const _SlowestEndpointsSection({required this.endpoints});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    if (endpoints.isEmpty) return const SizedBox.shrink();

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.obsSlowestEndpoints, style: AppTypography.subtitle.copyWith(color: scheme.title)),
            const SizedBox(height: AppSpacing.md),
            ...endpoints.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(children: [
                SBadge(label: e.method, variant: e.method == 'GET'
                    ? SBadgeVariant.success : SBadgeVariant.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(e.path, style: AppTypography.body.copyWith(color: scheme.body),
                    overflow: TextOverflow.ellipsis)),
                const SizedBox(width: AppSpacing.sm),
                Text('avg ${e.avgDurationMs.toStringAsFixed(0)}ms',
                    style: AppTypography.caption.copyWith(color: SellioColors.amber, fontWeight: FontWeight.w600)),
                const SizedBox(width: AppSpacing.sm),
                Text('p95 ${e.p95DurationMs.toStringAsFixed(0)}ms',
                    style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11)),
                const SizedBox(width: AppSpacing.sm),
                Text('${e.callCount}x', style: AppTypography.caption.copyWith(color: scheme.hint)),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Errors ──────────────────────────────────────────

class _RecentErrorsSection extends StatelessWidget {
  final List<RecentErrorEntity> errors;
  const _RecentErrorsSection({required this.errors});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.alertCircle, size: 18, color: SellioColors.red),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsRecentErrors, style: AppTypography.subtitle.copyWith(color: scheme.title)),
              const Spacer(),
              SBadge(label: errors.length.toString(), variant: SBadgeVariant.error),
            ]),
            const SizedBox(height: AppSpacing.md),
            ...errors.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(children: [
                SBadge(label: e.statusCode.toString(), variant: SBadgeVariant.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e.method} ${e.path}', style: AppTypography.caption.copyWith(
                      color: scheme.body, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  Text(e.error, style: AppTypography.caption.copyWith(
                      color: scheme.hint, fontSize: 11), overflow: TextOverflow.ellipsis),
                ])),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Live Call Feed ──────────────────────────────────────────

class _LiveCallFeed extends StatelessWidget {
  final List<ApiCallEntity> calls;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  const _LiveCallFeed({required this.calls, required this.hasMore,
    required this.isLoadingMore, required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return SCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(LucideIcons.radio, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.obsLiveFeed, style: AppTypography.subtitle.copyWith(color: scheme.title)),
              const Spacer(),
              Text('${calls.length} ${l10n.obsRecords}',
                  style: AppTypography.caption.copyWith(color: scheme.hint)),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (calls.isEmpty)
              Center(child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(l10n.obsNoData, style: AppTypography.body.copyWith(color: scheme.hint)),
              ))
            else ...[
              ...calls.take(30).map((call) => _ApiCallTile(call: call)),
              if (hasMore) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(child: isLoadingMore
                    ? SLoading()
                    : SButton(child: Text(l10n.obsLoadMore), onPressed: onLoadMore)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── API Call Tile ───────────────────────────────────────────

class _ApiCallTile extends StatelessWidget {
  final ApiCallEntity call;
  const _ApiCallTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: call.isError ? SellioColors.red.withAlpha(10) : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: call.isError ? SellioColors.red.withAlpha(30) : scheme.stroke),
        ),
        child: Row(children: [
          SizedBox(width: 54, child: SBadge(label: call.method,
              variant: call.method == 'GET' ? SBadgeVariant.success
                  : call.method == 'DELETE' ? SBadgeVariant.error : SBadgeVariant.primary)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
            decoration: BoxDecoration(
              color: _sourceColor(call.source).withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(call.source, style: AppTypography.caption.copyWith(
                color: _sourceColor(call.source), fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(call.path, style: AppTypography.caption.copyWith(
              color: scheme.body, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpacing.sm),
          SBadge(label: call.statusCode.toString(),
              variant: call.isError ? SBadgeVariant.error : SBadgeVariant.success),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(width: 70, child: Text('${call.durationMs.toStringAsFixed(1)}ms',
              style: AppTypography.caption.copyWith(
                  color: call.durationMs > 1000 ? SellioColors.red
                      : call.durationMs > 200 ? SellioColors.amber : scheme.hint,
                  fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
        ]),
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source) { case 'internal': return SellioColors.blue; case 'github': return SellioColors.purple;
      case 'google': return SellioColors.green; default: return SellioColors.amber; }
  }
}
