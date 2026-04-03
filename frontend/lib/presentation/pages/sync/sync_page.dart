import 'package:flutter/material.dart';
import 'package:hux/hux.dart';
import 'package:provider/provider.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/sync/providers/sync_provider.dart';

class SyncPage extends StatelessWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GitHub Data Sync',
              style: AppTypography.headline.copyWith(color: scheme.title),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _SyncSectionBody(),
          ],
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────

class _SyncSectionBody extends StatefulWidget {
  const _SyncSectionBody();

  @override
  State<_SyncSectionBody> createState() => _SyncSectionBodyState();
}

class _SyncSectionBodyState extends State<_SyncSectionBody> {
  @override
  void initState() {
    super.initState();
    // Load repo list on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sync = context.read<SyncProvider>();
      if (sync.repos.isEmpty) sync.loadRepos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Repo selector (shown when idle / done / error) ───
        if (!sync.isRunning && sync.repos.isNotEmpty) ...[
          _RepoSelector(sync: sync, scheme: scheme),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!sync.isRunning && sync.repos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Loading repositories…',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
          ),

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

        // ── Per-repo list (progress view) ────────────────────
        if (sync.status == SyncStatus.running)
          _RepoList(sync: sync),

        // ── Per-repo results (done view) ─────────────────────
        if (sync.status == SyncStatus.done || sync.status == SyncStatus.error)
          _RepoList(sync: sync),

        // ── Action buttons ───────────────────────────────────
        _ActionRow(sync: sync),
      ],
    );
  }
}

// ── Repo Selector ────────────────────────────────────────────────────

class _RepoSelector extends StatelessWidget {
  final SyncProvider sync;
  final dynamic scheme;
  const _RepoSelector({required this.sync, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final allSelected = sync.selectedRepoNames.length == sync.repos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Select repos to sync (${sync.selectedRepoNames.length}/${sync.repos.length})',
              style: AppTypography.caption.copyWith(color: scheme.hint),
            ),
            const Spacer(),
            TextButton(
              onPressed: allSelected ? sync.deselectAll : sync.selectAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                allSelected ? 'Deselect all' : 'Select all',
                style: AppTypography.caption.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.stroke),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sync.repos.length,
            separatorBuilder: (_, __) => Divider(color: scheme.stroke, height: 1),
            itemBuilder: (context, i) {
              final repo = sync.repos[i];
              final selected = sync.selectedRepoNames.contains(repo.fullName);
              return InkWell(
                onTap: () => sync.toggleRepoSelection(repo),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      SCheckbox(
                        value: selected,
                        onChanged: (_) => sync.toggleRepoSelection(repo),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          repo.name,
                          style: AppTypography.caption.copyWith(
                            color: selected ? scheme.title : scheme.hint,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
      SyncStatus.done      => HuxProgressVariant.success,
      SyncStatus.error     => HuxProgressVariant.destructive,
      SyncStatus.resetting => HuxProgressVariant.destructive,
      _                    => HuxProgressVariant.primary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HuxProgress(
          value: sync.progress,
          min: 0,
          max: 1,
          label: sync.status == SyncStatus.resetting
              ? 'Resetting database and caches…'
              : sync.progressLabel,
          showValue: sync.status != SyncStatus.resetting,
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
    final totalWarn  = results.fold<int>(0, (s, r) => s + r.fetchFailures.length);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _Chip(icon: Icons.merge_type, label: '$totalPrs PRs', color: scheme.primary),
        _Chip(icon: Icons.add_circle_outline, label: '+$totalAdd lines', color: scheme.green),
        _Chip(icon: Icons.remove_circle_outline, label: '-$totalDel lines', color: scheme.red),
        _Chip(icon: Icons.comment_outlined, label: '$totalCmt comments', color: scheme.secondary),
        if (totalWarn > 0)
          _Chip(
            icon: Icons.warning_amber_rounded,
            label: '$totalWarn API fetch failures',
            color: Colors.orange,
          ),
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
    // Show only the repos that were / are being synced
    final displayRepos = sync.status == SyncStatus.running
        ? sync.selectedRepos
        : sync.results.map((r) => r.repo).toList();

    return Column(
      children: [
        ...List.generate(displayRepos.length, (i) {
          final repo   = displayRepos[i];
          final result = sync.results.cast<RepoSyncResult?>()
              .firstWhere(
                  (r) => r?.repo.fullName == repo.fullName,
                  orElse: () => null);
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

    final fetchFailures = result.fetchFailures;

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...items.map((item) {
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
        }),
        // Warning chip shown only when some PRs failed to fetch API payload
        if (fetchFailures.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.red.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: scheme.red),
                    const SizedBox(width: 6),
                    Text(
                      '${fetchFailures.length} PRs failed to fetch deep payload data:',
                      style: AppTypography.caption.copyWith(
                          color: scheme.red, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...fetchFailures.map((failure) {
                  final pr = failure['prNumber'];
                  final error = failure['error'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: SelectableText(
                      '#$pr: $error',
                      style: AppTypography.caption.copyWith(
                          color: scheme.red.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          height: 1.3),
                    ),
                  );
                }),
              ],
            ),
          ),
      ],
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
    final hasFailed = sync.results.any((r) => !r.success || r.fetchFailures.isNotEmpty);
    final isIdle = sync.status == SyncStatus.idle ||
        sync.status == SyncStatus.done ||
        sync.status == SyncStatus.error;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // ── Primary sync / syncing button ─────────────────────
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
              Text(sync.isRunning ? 'Syncing…' : 'Sync Selected Repos'),
            ],
          ),
        ),

        // ── Retry failed repos ────────────────────────────────
        if (!sync.isRunning && hasFailed)
          SButton(
            variant: SButtonVariant.outline,
            onPressed: () => context.read<SyncProvider>().retryFailed(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.replay, size: 14),
                SizedBox(width: 4),
                Text('Retry Failed'),
              ],
            ),
          ),

        // ── Reset UI state ────────────────────────────────────
        if (sync.status == SyncStatus.done || sync.status == SyncStatus.error) ...[
          SButton(
            variant: SButtonVariant.outline,
            onPressed: () => context.read<SyncProvider>().reset(),
            child: const Text('Reset'),
          ),
        ],

        // ── Invalidate Cache ──────────────────────────────────
        if (isIdle)
          SButton(
            variant: SButtonVariant.outline,
            onPressed: sync.status == SyncStatus.resetting
                ? null
                : () => context.read<SyncProvider>().invalidateCache(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cleaning_services_outlined, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                Text('Clear Cache'),
              ],
            ),
          ),

        // ── Delete Database (danger) ───────────────────────────
        if (isIdle)
          SButton(
            variant: SButtonVariant.outline,
            onPressed: sync.status == SyncStatus.resetting
                ? null
                : () => _confirmReset(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_sweep_outlined, size: 14, color: scheme.red),
                const SizedBox(width: 4),
                Text(
                  'Delete Database',
                  style: TextStyle(color: scheme.red),
                ),
              ],
            ),
          ),

        // ── Global error ──────────────────────────────────────
        if (sync.status == SyncStatus.error && sync.globalError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sync.globalError!,
                style: AppTypography.caption.copyWith(color: scheme.red),
                maxLines: 2),
          ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Sync Data?'),
        content: const Text(
          'This will permanently delete ALL synced PRs and comments from the database '
          'and bust all caches.\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Database'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SyncProvider>().resetDatabase();
    }
  }
}
