import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class MembersHeader extends StatelessWidget {
  final int activeCount;
  final int inactiveCount;

  const MembersHeader({
    super.key,
    required this.activeCount,
    required this.inactiveCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.navMembers,
          style: AppTypography.title.copyWith(
            color: scheme.title,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.membersSubtitle(activeCount, inactiveCount),
          style: AppTypography.caption.copyWith(
            color: scheme.hint,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
