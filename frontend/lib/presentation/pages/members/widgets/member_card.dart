import 'package:flutter/material.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/member_status_entity.dart';
import 'member_avatar_section.dart';
import 'member_status_badge.dart';
import 'member_status_indicator.dart';
import 'member_activity_text.dart';

class MemberCard extends StatelessWidget {
  final MemberStatusEntity member;

  const MemberCard({super.key, required this.member});

  /// Green for active, red for inactive.
  static const _activeColor = Color(0xFF22C55E);
  static const _inactiveColor = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final isDark = context.isDark;
    final accent = member.isActive ? _activeColor : _inactiveColor;

    return Container(
      decoration: BoxDecoration(
        // Gradient background — matches SpotlightCard pattern
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.12 : 0.06),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Status indicator dot — top right
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: MemberStatusIndicator(
              isActive: member.isActive,
            ),
          ),

          // Card content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar + Name
                MemberAvatarSection(
                  name: member.developer,
                  avatarUrl: member.avatarUrl,
                  isActive: member.isActive,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Last active date
                MemberActivityText(
                  lastActiveDate: member.lastActiveDate,
                ),
                const SizedBox(height: AppSpacing.md),

                // Status badge
                MemberStatusBadge(isActive: member.isActive),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
