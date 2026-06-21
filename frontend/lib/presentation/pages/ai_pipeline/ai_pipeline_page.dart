// ─── AI Pipeline Page ────────────────────────────────────────────────────────────
//
// Traces and monitors live execution of AI ticket implementations.
// Integrates with WebSocket to receive real-time push events from the DO.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/data/datasources/ai_pipeline/ai_runs_websocket_data_source.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/ai_run_entity.dart';
import 'package:sellio_metrics/presentation/pages/ai_pipeline/providers/ai_pipeline_provider.dart';

class AiPipelinePage extends StatefulWidget {
  const AiPipelinePage({super.key});

  @override
  State<AiPipelinePage> createState() => _AiPipelinePageState();
}

class _AiPipelinePageState extends State<AiPipelinePage> {
  final Set<String> _expandedTaskIds = {};

  void _toggleExpand(String taskId) {
    setState(() {
      if (_expandedTaskIds.contains(taskId)) {
        _expandedTaskIds.remove(taskId);
      } else {
        _expandedTaskIds.add(taskId);
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _showClearHistoryDialog(BuildContext context) async {
    final scheme = context.colors;
    final provider = context.read<AiPipelineProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text(
          'Clear History?',
          style: AppTypography.title.copyWith(color: scheme.title),
        ),
        content: Text(
          'This will remove all completed and failed runs from your history. This action cannot be undone.',
          style: AppTypography.body.copyWith(color: scheme.hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SButton(
            variant: SButtonVariant.primary,
            primaryColor: SellioColors.red,
            size: SButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.clearHistory();
    }
  }

  Future<void> _showDeleteRunDialog(BuildContext context, String taskId) async {
    final scheme = context.colors;
    final provider = context.read<AiPipelineProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Text(
          'Delete Run?',
          style: AppTypography.title.copyWith(color: scheme.title),
        ),
        content: Text(
          'This will delete this run record. This action cannot be undone.',
          style: AppTypography.body.copyWith(color: scheme.hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          SButton(
            variant: SButtonVariant.primary,
            primaryColor: SellioColors.red,
            size: SButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await provider.deleteRun(taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiPipelineProvider>(
      builder: (context, provider, _) {
        final active = provider.activeRuns;
        final history = provider.historyRuns;
        final isInitialLoading = !provider.isLoaded &&
            provider.connectionStatus != WsConnectionStatus.disconnected;

        return Column(
          children: [
            _buildHeader(context, provider.connectionStatus),
            Expanded(
              child: isInitialLoading
                  ? _buildLoadingState(context)
                  : provider.runs.isEmpty
                      ? _buildEmptyState(context)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 900;
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildActiveSection(context, active),
                                    ),
                                    const SizedBox(width: AppSpacing.xl),
                                    Expanded(
                                      flex: 2,
                                      child: _buildHistorySection(context, history),
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildActiveSection(context, active),
                                    const SizedBox(height: AppSpacing.xl),
                                    _buildHistorySection(context, history),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, WsConnectionStatus status) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.stroke)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(LucideIcons.bot, size: 18, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'AI Agent Monitor',
            style: AppTypography.subtitle.copyWith(
              color: scheme.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _buildConnectionIndicator(context, status),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(BuildContext context, WsConnectionStatus status) {
    switch (status) {
      case WsConnectionStatus.connected:
        return const _LivePulseIndicator();
      case WsConnectionStatus.connecting:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Connecting...',
              style: AppTypography.caption.copyWith(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case WsConnectionStatus.disconnected:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Disconnected • retrying…',
              style: AppTypography.caption.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
    }
  }

  // ─── Sections ──────────────────────────────────────────────────────────────

  Widget _buildActiveSection(BuildContext context, List<AiRunEntity> active) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.activity, size: 16, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'ACTIVE PIPELINES',
              style: AppTypography.overline.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${active.length}',
                style: AppTypography.caption.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (active.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: scheme.stroke),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.checkCircle2, size: 36, color: scheme.hint.withValues(alpha: 0.5)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No Active Implementation Runs',
                  style: AppTypography.body.copyWith(
                    color: scheme.title,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'All tasks are completed or inactive.',
                  style: AppTypography.caption.copyWith(color: scheme.hint),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: active.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final run = active[index];
              return _PulsingActiveCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRunHeader(context, run, isActive: true),
                      const Divider(height: AppSpacing.xl),
                      _buildTimeline(context, run.events),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHistorySection(BuildContext context, List<AiRunEntity> history) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.history, size: 16, color: scheme.hint),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'HISTORY',
              style: AppTypography.overline.copyWith(
                color: scheme.hint,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.stroke,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${history.length}',
                style: AppTypography.caption.copyWith(
                  color: scheme.hint,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (history.isNotEmpty) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showClearHistoryDialog(context),
                icon: Icon(LucideIcons.trash2, size: 14, color: scheme.red),
                label: Text(
                  'Clear All',
                  style: AppTypography.caption.copyWith(
                    color: scheme.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: scheme.stroke),
            ),
            child: Center(
              child: Text(
                'No history available',
                style: AppTypography.caption.copyWith(color: scheme.hint),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final run = history[index];
              final isExpanded = _expandedTaskIds.contains(run.taskId);

              return Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: scheme.stroke),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(top: Radius.circular(8))
                          : AppRadius.mdAll,
                      onTap: () => _toggleExpand(run.taskId),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${run.issueNumber} ${run.issueTitle}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body.copyWith(
                                      color: scheme.title,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${run.owner}/${run.repo} • Completed ${DateFormat.yMMMd().format(run.updatedAt)}',
                                    style: AppTypography.caption.copyWith(
                                      color: scheme.hint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _buildStatusBadge(run.status),
                            const SizedBox(width: AppSpacing.sm),
                            GestureDetector(
                              onTap: () => _showDeleteRunDialog(context, run.taskId),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                  child: Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: scheme.red,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                              size: 16,
                              color: scheme.hint,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRunHeader(context, run, isActive: false),
                            const Divider(height: AppSpacing.lg),
                            _buildTimeline(context, run.events),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ─── Details Rendering ─────────────────────────────────────────────────────

  Widget _buildRunHeader(BuildContext context, AiRunEntity run, {required bool isActive}) {
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${run.issueNumber} ${run.issueTitle}',
                    style: AppTypography.title.copyWith(
                      color: scheme.title,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${run.owner}/${run.repo} • Task: ${run.taskId}',
                    style: AppTypography.caption.copyWith(
                      color: scheme.hint,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) _buildStatusBadge(run.status),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SButton(
              variant: SButtonVariant.outline,
              onPressed: () => _openUrl(run.issueUrl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.globe, size: 14, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  const Text('View Issue'),
                ],
              ),
            ),
            if (run.prNumber != null && run.prUrl != null) ...[
              const SizedBox(width: AppSpacing.sm),
              SButton(
                variant: SButtonVariant.primary,
                onPressed: () => _openUrl(run.prUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.gitPullRequest, size: 14, color: scheme.onPrimary),
                    const SizedBox(width: AppSpacing.xs),
                    Text('View PR #${run.prNumber}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(AiRunStatus status) {
    switch (status) {
      case AiRunStatus.inProgress:
        return SBadge(label: 'In Progress', variant: SBadgeVariant.primary);
      case AiRunStatus.ciPolling:
        return SBadge(label: 'CI Polling', variant: SBadgeVariant.primary);
      case AiRunStatus.completed:
        return SBadge(label: 'Completed', variant: SBadgeVariant.success);
      case AiRunStatus.failed:
        return SBadge(label: 'Failed', variant: SBadgeVariant.error);
    }
  }

  Widget _buildTimeline(BuildContext context, List<AiRunEventEntity> events) {
    final scheme = context.colors;

    if (events.isEmpty) {
      return Center(
        child: Text(
          'No event trace logs yet',
          style: AppTypography.caption.copyWith(color: scheme.hint),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  _buildEventIndicator(context, event.status),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: scheme.stroke,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.label,
                              style: AppTypography.body.copyWith(
                                color: scheme.title,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat.jm().format(event.timestamp),
                            style: AppTypography.caption.copyWith(
                              color: scheme.hint,
                            ),
                          ),
                        ],
                      ),
                      if (event.detail != null && event.detail!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          event.detail!,
                          style: AppTypography.caption.copyWith(
                            color: scheme.hint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventIndicator(BuildContext context, AiRunEventStatus status) {
    final scheme = context.colors;

    switch (status) {
      case AiRunEventStatus.done:
        return Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.white),
        );
      case AiRunEventStatus.failed:
        return Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, size: 12, color: Colors.white),
        );
      case AiRunEventStatus.running:
        return Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
        );
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    final scheme = context.colors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Connecting to AI Agent Hub…',
            style: AppTypography.body.copyWith(
              color: scheme.hint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = context.colors;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.bot,
                size: 48,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No AI Agent Runs Yet',
              style: AppTypography.title.copyWith(
                color: scheme.title,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Drag a ticket to the "AI Implement" column in your project board to trigger the AI agent and trace its live execution here.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: scheme.hint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Premium Widgets ──────────────────────────────────────────────────

class _LivePulseIndicator extends StatefulWidget {
  const _LivePulseIndicator();

  @override
  State<_LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<_LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF10B981);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1.0 + _controller.value * 0.8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: greenColor.withValues(alpha: 0.4 * (1 - _controller.value)),
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: greenColor,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Live',
          style: AppTypography.caption.copyWith(
            color: greenColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PulsingActiveCard extends StatefulWidget {
  final Widget child;
  const _PulsingActiveCard({required this.child});

  @override
  State<_PulsingActiveCard> createState() => _PulsingActiveCardState();
}

class _PulsingActiveCardState extends State<_PulsingActiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _borderColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scheme = context.colors;
    _borderColor = ColorTween(
      begin: scheme.primary.withValues(alpha: 0.15),
      end: scheme.primary.withValues(alpha: 0.6),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: _borderColor.value ?? scheme.primary,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_borderColor.value ?? scheme.primary).withValues(alpha: 0.05),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
