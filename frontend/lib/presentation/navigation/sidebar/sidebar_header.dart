import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_logo.dart';
import 'package:sellio_metrics/presentation/navigation/sidebar/sidebar_collapse_toggle.dart';

/// Sidebar header containing the brand logo, app title, and collapse toggle.
///
/// Renders two layouts:
/// - **Expanded**: logo + title/subtitle row + optional toggle on the right
/// - **Collapsed**: logo centred vertically + optional toggle below
class SidebarHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const SidebarHeader({
    super.key,
    required this.isCollapsed,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            const SidebarLogo(),
            const SizedBox(height: AppSpacing.sm),
            if (onToggleCollapse != null)
              SidebarCollapseToggle(
                isCollapsed: isCollapsed,
                onTap: onToggleCollapse!,
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const SidebarLogo(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.appTitle,
                  style: AppTypography.subtitle.copyWith(
                    color: scheme.title,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.appSubtitle,
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onToggleCollapse != null)
            SidebarCollapseToggle(
              isCollapsed: isCollapsed,
              onTap: onToggleCollapse!,
            ),
        ],
      ),
    );
  }
}
