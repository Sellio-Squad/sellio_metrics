
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/repo_info.dart';
import 'package:sellio_metrics/presentation/pages/leaderboard/providers/leaderboard_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
/// Full filter bar: quick preset chips + multi-repo dropdown + custom dates.
// ─────────────────────────────────────────────────────────────────────────────
class LeaderboardFilterBar extends StatelessWidget {
  const LeaderboardFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: preset chips + repo multi-select
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...LeaderboardPreset.values.map(
                  (p) => _PresetChip(preset: p),
                ),
                const SizedBox(width: AppSpacing.xs),
                const _RepoMultiSelect(),
                if (provider.hasActiveFilters)
                  _ClearChip(onTap: provider.clearAllFilters),
              ],
            ),
            // Row 2: custom date pickers (only when Custom preset)
            if (provider.preset == LeaderboardPreset.custom) ...[
              const SizedBox(height: AppSpacing.sm),
              const _CustomDateRow(),
            ],
          ],
        );
      },
    );
  }
}

// ─── Preset chip ──────────────────────────────────────────────────────────────

class _PresetChip extends StatelessWidget {
  final LeaderboardPreset preset;
  const _PresetChip({required this.preset});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<LeaderboardProvider>();
    final selected = provider.preset == preset;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: () => provider.setPreset(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceLow,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: selected ? scheme.primary : scheme.stroke,
              width: 1.5,
            ),
          ),
          child: Text(
            preset.label,
            style: AppTypography.caption.copyWith(
              color: selected ? scheme.onPrimary : scheme.body,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Repo multi-select dropdown ───────────────────────────────────────────────

class _RepoMultiSelect extends StatefulWidget {
  const _RepoMultiSelect();

  @override
  State<_RepoMultiSelect> createState() => _RepoMultiSelectState();
}

class _RepoMultiSelectState extends State<_RepoMultiSelect> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  void _open(BuildContext context) {
    if (_overlay != null) {
      _close();
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final provider = context.read<LeaderboardProvider>();
    
    _overlay = OverlayEntry(
      builder: (_) => ChangeNotifierProvider<LeaderboardProvider>.value(
        value: provider,
        child: _RepoDropdownOverlay(
          layerLink: _layerLink,
          anchorSize: size,
          onClose: _close,
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<LeaderboardProvider>();
    final selectedCount = provider.selectedRepoIds.length;
    final hasFilter = selectedCount > 0;
    final label = hasFilter ? '$selectedCount repo${selectedCount > 1 ? 's' : ''}' : 'All Repos';

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: () {
          context.read<LeaderboardProvider>().loadAvailableRepos();
          _open(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: hasFilter ? scheme.primaryVariant : scheme.surfaceLow,
            borderRadius: AppRadius.smAll,
            border: Border.all(
              color: hasFilter ? scheme.primary : scheme.stroke,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.gitBranch,
                size: 12,
                color: hasFilter ? scheme.primary : scheme.hint,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: hasFilter ? scheme.primary : scheme.body,
                  fontWeight: hasFilter ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                LucideIcons.chevronDown,
                size: 11,
                color: hasFilter ? scheme.primary : scheme.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Repo dropdown overlay ────────────────────────────────────────────────────

class _RepoDropdownOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final Size anchorSize;
  final VoidCallback onClose;

  const _RepoDropdownOverlay({
    required this.layerLink,
    required this.anchorSize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss layer
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown
        CompositedTransformFollower(
          link: layerLink,
          offset: Offset(0, anchorSize.height + 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Consumer<LeaderboardProvider>(
              builder: (context, provider, _) {
                final scheme = context.colors;
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 240,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(color: scheme.stroke),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Filter by Repo',
                                style: AppTypography.caption.copyWith(
                                  color: scheme.hint,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              if (provider.selectedRepoIds.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    provider.clearRepoFilter();
                                    onClose();
                                  },
                                  child: Text(
                                    'Clear',
                                    style: AppTypography.caption.copyWith(
                                      color: scheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(color: scheme.stroke, height: 1),
                        if (provider.reposLoading)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          )
                        else if (provider.availableRepos.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'No synced repos found',
                              style: AppTypography.caption.copyWith(color: scheme.hint),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                children: provider.availableRepos
                                    .map((repo) => _RepoCheckboxTile(repo: repo))
                                    .toList(),
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
        ),
      ],
    );
  }
}

// ─── Repo checkbox tile ───────────────────────────────────────────────────────

class _RepoCheckboxTile extends StatelessWidget {
  final RepoInfo repo;
  const _RepoCheckboxTile({required this.repo});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Consumer<LeaderboardProvider>(
      builder: (context, provider, _) {
        final selected = provider.selectedRepoIds.contains(repo.id);
        return InkWell(
          onTap: () => provider.toggleRepo(repo.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected ? scheme.primary : scheme.stroke,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Icon(Icons.check, size: 11, color: scheme.onPrimary)
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repo.name,
                        style: AppTypography.body.copyWith(
                          color: scheme.title,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${repo.id}',
                        style: AppTypography.caption.copyWith(
                          color: scheme.hint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Custom date row ─────────────────────────────────────────────────────────

class _CustomDateRow extends StatelessWidget {
  const _CustomDateRow();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final provider = context.watch<LeaderboardProvider>();
    return Row(
      children: [
        Icon(LucideIcons.calendar, size: 13, color: scheme.hint),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'From',
          style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 12),
        ),
        const SizedBox(width: AppSpacing.sm),
        SDatePicker(
          placeholder: 'Start date',
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDate: provider.customStart,
          onDateChanged: (date) {
            provider.setCustomDateRange(date, provider.customEnd);
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'To',
          style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 12),
        ),
        const SizedBox(width: AppSpacing.sm),
        SDatePicker(
          placeholder: 'End date',
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          initialDate: provider.customEnd,
          onDateChanged: (date) {
            provider.setCustomDateRange(provider.customStart, date);
          },
        ),
      ],
    );
  }
}

// ─── Clear all chip ───────────────────────────────────────────────────────────

class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: scheme.redVariant,
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, size: 12, color: scheme.red),
            const SizedBox(width: 3),
            Text(
              'Clear',
              style: AppTypography.caption.copyWith(
                color: scheme.red,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
