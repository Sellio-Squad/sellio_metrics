/// Setting — SyncSection Widget
///
/// Animated multi-repo sync UI using HuxProgress.
/// Each repo cycles: pending → in-progress (indeterminate) → done/error.
/// Completion card shows: PRs · Lines added/deleted · Comments.
library;

import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../design_system/design_system.dart';
import '../providers/sync_provider.dart';

class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  @override
  Widget build(BuildContext context) => const _SyncSectionBody();
}

// ── Body ─────────────────────────────────────────────────────────────

class _SyncSectionBody extends StatelessWidget {
  const _SyncSectionBody();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Overall progress bar ─────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: sync.status != SyncStatus.idle
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _OverallProgress(sync: sync),
                )
              : const SizedBox.shrink(),
        ),

        // ── Per-repo list ────────────────────────────────────
        if (sync.repos.isNotEmpty && sync.status != SyncStatus.idle)
          _RepoList(sync: sync),

        // ── Action buttons ───────────────────────────────────
        _ActionRow(sync: sync),
      ],
    );
  }
}

// ── Overall HuxProgress ──────────────────────────────────────────────

class _OverallProgress extends StatelessWidget {
  final SyncProvider sync;
  const _OverallProgress({required this.sync});

  @override
  Widget build(BuildContext context) {
    final variant = switch (sync.status) {
      SyncStatus.done  => HuxProgressVariant.success,
      SyncStatus.error => HuxProgressVariant.destructive,
      _                => HuxProgressVariant.primary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HuxProgress(
          value: sync.progress,
          min: 0,
          max: 1,
          label: sync.progressLabel,
          showValue: true,
          size: HuxProgressSize.large,
          variant: variant,
        ),
        // Summary row when done
        if (sync.status == SyncStatus.done) ...[
          const SizedBox(height: AppSpacing.sm),
          _SyncSummaryRow(results: sync.results),
        ],
      ],
    );
  }
}

// ── Summary chips after full sync ───────────────────────────────────

class _SyncSummaryRow extends StatelessWidget {
  final List<RepoSyncResult> results;
  const _SyncSummaryRow({required this.results});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final totalPrs   = results.fold(0, (s, r) => s + (r.prsUpserted ?? 0));
    final totalCmt   = results.fold(0, (s, r) => s + (r.commentsInserted ?? 0));
    final totalAdd   = results.fold(0, (s, r) => s + (r.linesAdded ?? 0));
    final totalDel   = results.fold(0, (s, r) => s + (r.linesDeleted ?? 0));

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(icon: Icons.merge_type, label: '$totalPrs PRs', color: scheme.primary),
        _Chip(icon: Icons.add_circle_outline, label: '+$totalAdd lines', color: scheme.green),
        _Chip(icon: Icons.remove_circle_outline, label: '-$totalDel lines', color: scheme.red),
        _Chip(icon: Icons.comment_outlined, label: '$totalCmt comments', color: scheme.secondary),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Repo List ────────────────────────────────────────────────────────

class _RepoList extends StatelessWidget {
  final SyncProvider sync;
  const _RepoList({required this.sync});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(sync.repos.length, (i) {
          final repo      = sync.repos[i];
          final result    = sync.results.length > i ? sync.results[i] : null;
          final isCurrent = sync.status == SyncStatus.running && i == sync.currentIndex;
          final isDone    = result != null;
          final isError   = isDone && !result.success;

          return _RepoSyncRow(
            key: ValueKey(repo.fullName),
            repoName: repo.name,
            isCurrent: isCurrent,
            isDone: isDone,
            isError: isError,
            isPending: !isDone && !isCurrent,
            result: result,
          );
        }),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// ── Individual Repo Row ──────────────────────────────────────────────

class _RepoSyncRow extends StatelessWidget {
  final String repoName;
  final bool isCurrent;
  final bool isDone;
  final bool isError;
  final bool isPending;
  final RepoSyncResult? result;

  const _RepoSyncRow({
    super.key,
    required this.repoName,
    required this.isCurrent,
    required this.isDone,
    required this.isError,
    required this.isPending,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.07)
              : isDone && !isError
                  ? scheme.green.withValues(alpha: 0.05)
                  : isError
                      ? scheme.red.withValues(alpha: 0.05)
                      : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.4)
                : isDone && !isError
                    ? scheme.green.withValues(alpha: 0.3)
                    : isError
                        ? scheme.red.withValues(alpha: 0.3)
                        : scheme.stroke.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status icon with animation
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _statusIcon(scheme),
                ),
                const SizedBox(width: AppSpacing.sm),

                Expanded(
                  child: Text(
                    repoName,
                    style: AppTypography.body.copyWith(
                      color: isPending
                          ? scheme.hint
                          : isError
                              ? scheme.red
                              : scheme.title,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),

                // Step label badge when active
                if (isCurrent)
                  _PulseBadge(label: 'Syncing'),
              ],
            ),

            // Indeterminate progress bar while active
            if (isCurrent) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 4),
              ),
            ],

            // Rich result stats after done
            if (isDone && !isError && result != null) ...[
              const SizedBox(height: 6),
              _RepoStats(result: result!),
            ],

            // Error text
            if (isError && result?.error != null) ...[
              const SizedBox(height: 4),
              Text(
                result!.error!,
                style: AppTypography.caption.copyWith(color: scheme.red),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(dynamic scheme) {
    if (isCurrent) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isError) {
      return Icon(key: const ValueKey('error'),
          Icons.error_outline, size: 18, color: Colors.red);
    }
    if (isDone) {
      return Icon(key: const ValueKey('done'),
          Icons.check_circle_outline, size: 18, color: Colors.green);
    }
    return Icon(key: const ValueKey('pending'),
        Icons.radio_button_unchecked, size: 18, color: scheme.hint);
  }
}

// ── Repo stats chips ─────────────────────────────────────────────────

class _RepoStats extends StatelessWidget {
  final RepoSyncResult result;
  const _RepoStats({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final items = <(IconData, String, Color)>[
      (Icons.merge_type, '${result.prsUpserted ?? 0} PRs', scheme.primary),
      (Icons.add, '+${result.linesAdded ?? 0}', scheme.green),
      (Icons.remove, '-${result.linesDeleted ?? 0}', scheme.red),
      (Icons.comment_outlined, '${result.commentsInserted ?? 0} comments', scheme.hint),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((item) {
        final (icon, label, color) = item;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 2),
            Text(label,
                style: AppTypography.caption.copyWith(
                    color: color, fontWeight: FontWeight.w500)),
          ],
        );
      }).toList(),
    );
  }
}

// ── Pulsing "Syncing" badge ──────────────────────────────────────────

class _PulseBadge extends StatefulWidget {
  final String label;
  const _PulseBadge({required this.label});

  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _fade = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return FadeTransition(
      opacity: _fade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.label,
          style: AppTypography.caption.copyWith(
              color: scheme.primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── Action buttons row ───────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final SyncProvider sync;
  const _ActionRow({required this.sync});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      children: [
        SButton(
          onPressed: sync.isRunning
              ? null
              : () => context.read<SyncProvider>().startSync(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sync.isRunning)
                const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.cloud_sync_outlined, size: 16),
              const SizedBox(width: AppSpacing.sm),
              Text(sync.isRunning ? 'Syncing…' : 'Sync All Repos'),
            ],
          ),
        ),
        if (sync.status == SyncStatus.done || sync.status == SyncStatus.error) ...[
          const SizedBox(width: AppSpacing.sm),
          SButton(
            variant: SButtonVariant.outline,
            onPressed: () => context.read<SyncProvider>().reset(),
            child: const Text('Reset'),
          ),
        ],
        // Global error
        if (sync.status == SyncStatus.error && sync.globalError != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(sync.globalError!,
                style: AppTypography.caption.copyWith(color: scheme.red),
                maxLines: 2),
          ),
        ],
      ],
    );
  }
}
