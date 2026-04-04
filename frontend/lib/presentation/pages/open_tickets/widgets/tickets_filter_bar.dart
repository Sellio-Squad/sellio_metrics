import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/pages/open_tickets/providers/tickets_provider.dart';

class TicketsFilterBar extends StatefulWidget {
  final TicketSourceFilter sourceFilter;
  final List<String> availableRepos;
  final List<String> availableAssignees;
  final List<String> availableLabels;
  final String? selectedRepo;
  final String? selectedAssignee;
  final String? selectedLabel;
  final String searchTerm;
  final ValueChanged<TicketSourceFilter> onSourceChanged;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRepoChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final ValueChanged<String?> onLabelChanged;
  final VoidCallback onClearFilters;

  const TicketsFilterBar({
    super.key,
    required this.sourceFilter,
    required this.availableRepos,
    required this.availableAssignees,
    required this.availableLabels,
    required this.selectedRepo,
    required this.selectedAssignee,
    required this.selectedLabel,
    required this.searchTerm,
    required this.onSourceChanged,
    required this.onSearch,
    required this.onRepoChanged,
    required this.onAssigneeChanged,
    required this.onLabelChanged,
    required this.onClearFilters,
  });

  @override
  State<TicketsFilterBar> createState() => _TicketsFilterBarState();
}

class _TicketsFilterBarState extends State<TicketsFilterBar> {
  int _inputKey = 0;

  bool get _hasActiveFilters =>
      widget.sourceFilter != TicketSourceFilter.all ||
      widget.selectedRepo != null ||
      widget.selectedAssignee != null ||
      widget.selectedLabel != null ||
      widget.searchTerm.isNotEmpty;

  void _handleClear() {
    setState(() => _inputKey++);
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Source tabs ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TicketSourceFilter.values.map((f) {
                  final isSelected = widget.sourceFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: _SourceChip(
                      label: f.label,
                      selected: isSelected,
                      onTap: () => widget.onSourceChanged(f),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: scheme.stroke, height: 1),
          // ── Search + Dropdowns ───────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;

                if (isNarrow) {
                  return Column(
                    children: [
                      SInput(
                        key: ValueKey('search_$_inputKey'),
                        hint: 'Search tickets…',
                        prefixIcon: Icon(LucideIcons.search, size: 16, color: scheme.hint),
                        onChanged: widget.onSearch,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(child: _Dropdown(
                          hint: 'Repo', icon: LucideIcons.gitBranch,
                          value: widget.selectedRepo, items: widget.availableRepos,
                          onChanged: widget.onRepoChanged,
                        )),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _Dropdown(
                          hint: 'Assignee', icon: LucideIcons.user,
                          value: widget.selectedAssignee, items: widget.availableAssignees,
                          onChanged: widget.onAssigneeChanged,
                        )),
                        if (_hasActiveFilters) ...[
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            icon: Icon(LucideIcons.x, size: 18, color: scheme.hint),
                            onPressed: _handleClear,
                          ),
                        ],
                      ]),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: SInput(
                      key: ValueKey('search_$_inputKey'),
                      hint: 'Search by title or author…',
                      prefixIcon: Icon(LucideIcons.search, size: 16, color: scheme.hint),
                      onChanged: widget.onSearch,
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: _Dropdown(
                      hint: 'Repository', icon: LucideIcons.gitBranch,
                      value: widget.selectedRepo, items: widget.availableRepos,
                      onChanged: widget.onRepoChanged,
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: _Dropdown(
                      hint: 'Assignee', icon: LucideIcons.user,
                      value: widget.selectedAssignee, items: widget.availableAssignees,
                      onChanged: widget.onAssigneeChanged,
                    )),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: _Dropdown(
                      hint: 'Label', icon: LucideIcons.tag,
                      value: widget.selectedLabel, items: widget.availableLabels,
                      onChanged: widget.onLabelChanged,
                    )),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Tooltip(
                        message: 'Clear all filters',
                        child: IconButton(
                          icon: Icon(LucideIcons.x, size: 18, color: scheme.hint),
                          onPressed: _handleClear,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Source Chip ──────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SourceChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: selected ? scheme.primary : scheme.stroke),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : scheme.hint,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── Dropdown ─────────────────────────────────────────────────

class _Dropdown extends StatelessWidget {
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.hint, required this.icon,
    required this.value, required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: value != null ? scheme.primary : scheme.stroke),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(children: [
            Icon(icon, size: 14, color: scheme.hint),
            const SizedBox(width: 6),
            Text(hint, style: AppTypography.caption.copyWith(color: scheme.hint)),
          ]),
          isExpanded: true,
          icon: Icon(LucideIcons.chevronsUpDown, size: 14, color: scheme.hint),
          dropdownColor: scheme.surfaceLow,
          borderRadius: AppRadius.mdAll,
          style: AppTypography.body.copyWith(color: scheme.title),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All', style: AppTypography.body.copyWith(color: scheme.hint)),
            ),
            ...items.map((item) => DropdownMenuItem<String?>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
