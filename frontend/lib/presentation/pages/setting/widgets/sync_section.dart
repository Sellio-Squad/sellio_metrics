/// Setting — SyncSection Widget
///
/// Displays an animated multi-repo sync UI using HuxProgress.
/// Each repo cycles through: pending → in-progress → done/error.
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

class _SyncSectionBody extends StatelessWidget {
  const _SyncSectionBody();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Overall progress bar ─────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: sync.status != SyncStatus.idle
              ? Padding(
                  key: const ValueKey('progress'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: HuxProgress(
                    value: sync.progress,
                    label: sync.progressLabel,
                    showValue: true,
                    size: HuxProgressSize.large,
                    variant: _overallVariant(sync.status),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),

        // ── Per-repo list ────────────────────────────────────────
        if (sync.repos.isNotEmpty && sync.status != SyncStatus.idle) ...[
          ...List.generate(sync.repos.length, (i) {
            final repo = sync.repos[i];
            final result = sync.results.length > i ? sync.results[i] : null;
            final isCurrent =
                sync.status == SyncStatus.running && i == sync.currentIndex;
            final isDone = result != null;
            final isError = isDone && !result.success;

            return _RepoSyncRow(
              repoName: repo.name,
              isCurrent: isCurrent,
              isDone: isDone,
              isError: isError,
              result: result,
              index: i,
              currentIndex: sync.currentIndex,
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],

        // ── Action buttons ───────────────────────────────────────
        Row(
          children: [
            SButton(
              onPressed: sync.isRunning ? null : () => context.read<SyncProvider>().startSync(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sync.isRunning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.sync, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(sync.isRunning ? 'Syncing...' : 'Sync All Repos'),
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
          ],
        ),

        // ── Error message ────────────────────────────────────────
        if (sync.status == SyncStatus.error && sync.globalError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              sync.globalError!,
              style: AppTypography.caption.copyWith(color: scheme.red),
            ),
          ),
      ],
    );
  }

  HuxProgressVariant _overallVariant(SyncStatus status) => switch (status) {
        SyncStatus.done => HuxProgressVariant.success,
        SyncStatus.error => HuxProgressVariant.destructive,
        _ => HuxProgressVariant.primary,
      };
}

// ── Individual Repo Row ──────────────────────────────────────────────

class _RepoSyncRow extends StatelessWidget {
  final String repoName;
  final bool isCurrent;
  final bool isDone;
  final bool isError;
  final RepoSyncResult? result;
  final int index;
  final int currentIndex;

  const _RepoSyncRow({
    required this.repoName,
    required this.isCurrent,
    required this.isDone,
    required this.isError,
    required this.result,
    required this.index,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isPending = !isDone && !isCurrent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isCurrent
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.3)
                : scheme.stroke.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _statusIcon(scheme, isPending, isCurrent, isError),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Repo name + mini progress when active
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
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
                  if (isCurrent) ...[
                    const SizedBox(height: 4),
                    HuxProgress(
                      value: 0.0,
                      size: HuxProgressSize.small,
                      variant: HuxProgressVariant.primary,
                    ),
                  ],
                  if (result != null && !isError) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${result!.prsUpserted ?? 0} PRs · ${result!.commentsInserted ?? 0} comments',
                      style: AppTypography.caption.copyWith(color: scheme.hint),
                    ),
                  ],
                  if (isError && result?.error != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      result!.error!,
                      style: AppTypography.caption.copyWith(color: scheme.red),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(
    dynamic scheme,
    bool isPending,
    bool isCurrent,
    bool isError,
  ) {
    if (isCurrent) {
      return const SizedBox(
        key: ValueKey('loading'),
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (isError) {
      return Icon(
        key: const ValueKey('error'),
        Icons.error_outline,
        size: 18,
        color: Colors.red,
      );
    }
    if (isDone) {
      return Icon(
        key: const ValueKey('done'),
        Icons.check_circle_outline,
        size: 18,
        color: Colors.green,
      );
    }
    return Icon(
      key: const ValueKey('pending'),
      Icons.radio_button_unchecked,
      size: 18,
      color: scheme.hint,
    );
  }
}
