import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class MemberStatusBadge extends StatelessWidget {
  final bool isActive;

  const MemberStatusBadge({super.key, required this.isActive});

  static const _activeColor = Color(0xFF22C55E);
  static const _inactiveColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.isDark;
    final color = isActive ? _activeColor : _inactiveColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: AppRadius.smAll,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small colored dot inside badge
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? l10n.memberStatusActive : l10n.memberStatusInactive,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? l10n.memberActiveDays : l10n.memberInactiveDays,
            style: AppTypography.caption.copyWith(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
