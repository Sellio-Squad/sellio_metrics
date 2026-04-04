import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';

class IssuesFilterBar extends StatefulWidget {
  final List<String> availableRepos;
  final List<String> availableAssignees;
  final List<String> availableLabels;
  final String? selectedRepo;
  final String? selectedAssignee;
  final String? selectedLabel;
  final String searchTerm;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onRepoChanged;
  final ValueChanged<String?> onAssigneeChanged;
  final ValueChanged<String?> onLabelChanged;
  final VoidCallback onClearFilters;

  const IssuesFilterBar({
    super.key,
    required this.availableRepos,
    required this.availableAssignees,
    required this.availableLabels,
    required this.selectedRepo,
    required this.selectedAssignee,
    required this.selectedLabel,
    required this.searchTerm,
    required this.onSearch,
    required this.onRepoChanged,
    required this.onAssigneeChanged,
    required this.onLabelChanged,
    required this.onClearFilters,
  });

  @override
  State<IssuesFilterBar> createState() => _IssuesFilterBarState();
}

class _IssuesFilterBarState extends State<IssuesFilterBar> {
  // Incrementing this key rebuilds SInput, effectively clearing it
  int _inputKey = 0;

  bool get _hasActiveFilters =>
      widget.selectedRepo != null ||
      widget.selectedAssignee != null ||
      widget.selectedLabel != null ||
      widget.searchTerm.isNotEmpty;

  void _handleClear() {
    setState(() => _inputKey++); // force SInput to rebuild (clear text)
    widget.onClearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.stroke),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          if (isNarrow) {
            return Column(
              children: [
                SInput(
                  key: ValueKey('search_$_inputKey'),
                  hint: 'Search by title…',
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: scheme.hint),
                  onChanged: widget.onSearch,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        hint: 'Repo',
                        icon: LucideIcons.gitBranch,
                        value: widget.selectedRepo,
                        items: widget.availableRepos,
                        onChanged: widget.onRepoChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _FilterDropdown(
                        hint: 'Assignee',
                        icon: LucideIcons.user,
                        value: widget.selectedAssignee,
                        items: widget.availableAssignees,
                        onChanged: widget.onAssigneeChanged,
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        icon: Icon(LucideIcons.x, size: 18, color: scheme.hint),
                        onPressed: _handleClear,
                        tooltip: 'Clear filters',
                      ),
                    ],
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              // ── Search ──
              Expanded(
                flex: 3,
                child: SInput(
                  key: ValueKey('search_$_inputKey'),
                  hint: 'Search by title or author…',
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: scheme.hint),
                  onChanged: widget.onSearch,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // ── Repo ──
              Expanded(
                flex: 2,
                child: _FilterDropdown(
                  hint: 'Repository',
                  icon: LucideIcons.gitBranch,
                  value: widget.selectedRepo,
                  items: widget.availableRepos,
                  onChanged: widget.onRepoChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // ── Assignee ──
              Expanded(
                flex: 2,
                child: _FilterDropdown(
                  hint: 'Assignee',
                  icon: LucideIcons.user,
                  value: widget.selectedAssignee,
                  items: widget.availableAssignees,
                  onChanged: widget.onAssigneeChanged,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // ── Label ──
              Expanded(
                flex: 2,
                child: _FilterDropdown(
                  hint: 'Label',
                  icon: LucideIcons.tag,
                  value: widget.selectedLabel,
                  items: widget.availableLabels,
                  onChanged: widget.onLabelChanged,
                ),
              ),
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
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String hint;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
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
          hint: Row(
            children: [
              Icon(icon, size: 14, color: scheme.hint),
              const SizedBox(width: 6),
              Text(hint, style: AppTypography.caption.copyWith(color: scheme.hint)),
            ],
          ),
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
            ...items.map(
              (item) => DropdownMenuItem<String?>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
