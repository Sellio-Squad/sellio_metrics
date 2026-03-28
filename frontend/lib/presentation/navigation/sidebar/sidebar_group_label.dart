import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/design_system/design_system.dart';
import 'package:sellio_metrics/core/navigation/app_navigation.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

/// Overline label shown above a group of nav items in the expanded sidebar.
class SidebarGroupLabel extends StatelessWidget {
  final NavGroup group;
  final AppLocalizations l10n;

  const SidebarGroupLabel({
    super.key,
    required this.group,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        group.label(l10n),
        style: AppTypography.overline.copyWith(
          color: scheme.hint,
          letterSpacing: 1.2,
          fontSize: 10,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
