import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';
import 'package:sellio_metrics/presentation/pages/setting/providers/app_settings_provider.dart';

/// Sidebar footer showing a theme toggle switch.
///
/// Collapses to an icon-only [Tooltip]-wrapped button when [isCollapsed].
class SidebarFooter extends StatelessWidget {
  final bool isCollapsed;

  const SidebarFooter({super.key, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final settings = context.watch<AppSettingsProvider>();
    final l10n = AppLocalizations.of(context);
    final isDark = settings.isDarkMode;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Tooltip(
          message: isDark ? l10n.themeDark : l10n.themeLight,
          child: InkWell(
            onTap: settings.toggleTheme,
            borderRadius: AppRadius.smAll,
            hoverColor: scheme.stroke.withValues(alpha: 0.3),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: SizedBox(
              height: 36,
              child: Center(
                child: Icon(
                  isDark ? LucideIcons.moon : LucideIcons.sun,
                  size: 18,
                  color: scheme.hint,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            isDark ? LucideIcons.moon : LucideIcons.sun,
            size: 18,
            color: scheme.hint,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isDark ? l10n.themeDark : l10n.themeLight,
              style: AppTypography.caption.copyWith(color: scheme.hint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SSwitch(
            value: isDark,
            onChanged: (_) => settings.toggleTheme(),
          ),
        ],
      ),
    );
  }
}
