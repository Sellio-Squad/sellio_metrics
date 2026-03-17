import 'package:flutter/material.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class MemberStatusBadge extends StatelessWidget {
  final bool isActive;

  const MemberStatusBadge({super.key, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? scheme.primaryVariant
            : scheme.disabled.withValues(alpha: 0.15),
        borderRadius: AppRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(isActive: isActive),
          const SizedBox(width: 6),
          Text(
            isActive
                ? l10n.memberStatusActive
                : l10n.memberStatusInactive,
            style: AppTypography.caption.copyWith(
              color: isActive ? scheme.primary : scheme.hint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool isActive;

  const _StatusDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? scheme.primary : scheme.hint,
      ),
    );
  }
}
