import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_constants.dart';

/// Button that toggles the sidebar between expanded and collapsed states.
///
/// Rotates the icon 180° when collapsed so the arrow always points
/// toward the open direction.
class SidebarCollapseToggle extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const SidebarCollapseToggle({
    super.key,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      hoverColor: scheme.stroke.withValues(alpha: 0.4),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: AnimatedRotation(
            duration: sidebarAnimDuration,
            turns: isCollapsed ? 0.5 : 0,
            child: Icon(
              LucideIcons.panelLeftClose,
              size: 16,
              color: scheme.hint,
            ),
          ),
        ),
      ),
    );
  }
}
