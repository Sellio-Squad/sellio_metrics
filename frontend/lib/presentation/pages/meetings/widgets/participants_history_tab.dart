// ─── Tab: Participants History ────────────────────────────────────────────────
//
// Shows all participants (joined + left) with search and filter controls.
// Used as the "History" tab content in MeetingDetailView.

import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/domain/entities/participant_entity.dart';
import 'package:sellio_metrics/presentation/pages/meetings/widgets/participant_row.dart';

enum ParticipantHistoryFilter { all, live, left }

class ParticipantsHistoryTab extends StatefulWidget {
  final List<ParticipantEntity> history;

  const ParticipantsHistoryTab({super.key, required this.history});

  @override
  State<ParticipantsHistoryTab> createState() => _ParticipantsHistoryTabState();
}

class _ParticipantsHistoryTabState extends State<ParticipantsHistoryTab> {
  String _searchQuery = '';
  ParticipantHistoryFilter _filter = ParticipantHistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    // ── Apply filter + search
    List<ParticipantEntity> filtered = List.of(widget.history);

    if (_filter == ParticipantHistoryFilter.live) {
      filtered = filtered.where((p) => p.isCurrentlyPresent).toList();
    } else if (_filter == ParticipantHistoryFilter.left) {
      filtered = filtered.where((p) => !p.isCurrentlyPresent).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.displayName.toLowerCase().contains(q) ||
              p.participantKey.toLowerCase().contains(q))
          .toList();
    }

    // Live first, then by start time desc
    filtered.sort((a, b) {
      if (a.isCurrentlyPresent && !b.isCurrentlyPresent) return -1;
      if (!a.isCurrentlyPresent && b.isCurrentlyPresent) return 1;
      return b.startTime.compareTo(a.startTime);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search + Filter bar
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;

              final searchField = SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search participants...',
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 16,
                      color: scheme.hint,
                    ),
                    filled: true,
                    fillColor: scheme.surfaceLow,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: scheme.stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: scheme.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide:
                          BorderSide(color: scheme.primary, width: 1.5),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    isDense: true,
                  ),
                  style: AppTypography.body.copyWith(
                    color: scheme.title,
                    fontSize: 13,
                  ),
                ),
              );

              final filterRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _filter == ParticipantHistoryFilter.all,
                    onTap: () => setState(
                        () => _filter = ParticipantHistoryFilter.all),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _FilterChip(
                    label: 'Live',
                    isSelected: _filter == ParticipantHistoryFilter.live,
                    onTap: () => setState(
                        () => _filter = ParticipantHistoryFilter.live),
                    dotColor: SellioColors.green,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _FilterChip(
                    label: 'Left',
                    isSelected: _filter == ParticipantHistoryFilter.left,
                    onTap: () => setState(
                        () => _filter = ParticipantHistoryFilter.left),
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: AppSpacing.md),
                    filterRow,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  searchField,
                  const SizedBox(height: AppSpacing.sm),
                  filterRow,
                ],
              );
            },
          ),
        ),

        Divider(height: 1, color: scheme.stroke),

        // ── List
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(LucideIcons.userX,
                    size: 36, color: scheme.hint.withValues(alpha: 0.3)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No participants match "$_searchQuery"'
                      : 'No participants yet',
                  style: AppTypography.body.copyWith(color: scheme.hint),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.stroke,
              indent: AppSpacing.lg,
              endIndent: AppSpacing.lg,
            ),
            itemBuilder: (_, i) => ParticipantRow(participant: filtered[i]),
          ),
      ],
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? dotColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.1)
                : scheme.surfaceLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.3)
                  : scheme.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? scheme.primary : scheme.hint,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
