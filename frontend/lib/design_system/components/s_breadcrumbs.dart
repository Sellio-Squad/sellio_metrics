/// SBreadcrumbs — Design System Component
///
/// A breadcrumb navigation bar that renders items separated by chevrons.
/// The last item is displayed as the current (non-clickable) page.
library;

import 'package:flutter/material.dart';

import '../../core/extensions/theme_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class SBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const SBreadcrumbItem({required this.label, this.onTap});
}

class SBreadcrumbs extends StatelessWidget {
  final List<SBreadcrumbItem> items;

  const SBreadcrumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: scheme.hint,
              ),
            ),
          ],
          _BreadcrumbChip(
            item: items[i],
            isCurrent: i == items.length - 1,
          ),
        ],
      ],
    );
  }
}

class _BreadcrumbChip extends StatefulWidget {
  final SBreadcrumbItem item;
  final bool isCurrent;

  const _BreadcrumbChip({required this.item, required this.isCurrent});

  @override
  State<_BreadcrumbChip> createState() => _BreadcrumbChipState();
}

class _BreadcrumbChipState extends State<_BreadcrumbChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isClickable = !widget.isCurrent && widget.item.onTap != null;

    return MouseRegion(
      cursor: isClickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: isClickable ? (_) => setState(() => _isHovered = true) : null,
      onExit: isClickable ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: isClickable ? widget.item.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: _isHovered
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.item.label,
            style: AppTypography.caption.copyWith(
              color: widget.isCurrent ? scheme.title : scheme.hint,
              fontWeight:
                  widget.isCurrent ? FontWeight.w600 : FontWeight.w400,
              decoration:
                  _isHovered ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
