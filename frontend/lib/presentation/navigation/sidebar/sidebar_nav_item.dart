import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_constants.dart';

/// A single navigation item in the sidebar.
///
/// Handles its own press-scale animation via [AnimationController].
/// Renders differently depending on [isCollapsed]:
/// - Expanded: icon + active indicator bar + label
/// - Collapsed: icon only with a [Tooltip]
class SidebarNavItem extends StatefulWidget {
  final AppRoute route;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const SidebarNavItem({
    super.key,
    required this.route,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
    required this.l10n,
  });

  @override
  State<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<SidebarNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final label = widget.route.labelBuilder(widget.l10n);
    final iconColor = widget.isSelected ? scheme.primary : scheme.hint;
    final textColor = widget.isSelected ? scheme.title : scheme.body;
    final bg = widget.isSelected ? scheme.primaryVariant : Colors.transparent;

    return Semantics(
      label: label,
      selected: widget.isSelected,
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: bg,
            borderRadius: AppRadius.smAll,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => _controller.forward(),
              onTapUp: (_) => _controller.reverse(),
              onTapCancel: () => _controller.reverse(),
              borderRadius: AppRadius.smAll,
              hoverColor: widget.isSelected
                  ? Colors.transparent
                  : scheme.stroke.withValues(alpha: 0.3),
              splashColor: scheme.primary.withValues(alpha: 0.05),
              highlightColor: Colors.transparent,
              child: SizedBox(
                height: 40,
                child: widget.isCollapsed
                    ? _buildCollapsed(iconColor, label, scheme)
                    : _buildExpanded(iconColor, textColor, label, scheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(
    Color iconColor,
    Color textColor,
    String label,
    SellioColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          // Animated active indicator bar
          AnimatedContainer(
            duration: sidebarAnimDuration,
            width: widget.isSelected ? 3 : 0,
            height: 18,
            margin: EdgeInsets.only(
              right: widget.isSelected ? AppSpacing.sm : 0,
            ),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: AppRadius.smAll,
            ),
          ),
          Icon(widget.route.icon, size: 20, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: textColor,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsed(
    Color iconColor,
    String label,
    SellioColorScheme scheme,
  ) {
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: sidebarAnimDuration,
              width: widget.isSelected ? 3 : 0,
              height: 18,
              margin: EdgeInsets.only(
                right: widget.isSelected ? 4 : 0,
              ),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: AppRadius.smAll,
              ),
            ),
            Icon(widget.route.icon, size: 20, color: iconColor),
          ],
        ),
      ),
    );
  }
}
