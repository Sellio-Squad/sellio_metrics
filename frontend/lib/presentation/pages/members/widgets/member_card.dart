import 'package:flutter/material.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../design_system/components/s_avatar.dart';
import '../../../../domain/entities/member_status_entity.dart';
import 'member_activity_text.dart';
import 'member_status_badge.dart';

class MemberCard extends StatelessWidget {
  final MemberStatusEntity member;

  const MemberCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: member.isActive
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.disabled.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildInfo(scheme)),
          const SizedBox(width: AppSpacing.sm),
          MemberStatusBadge(isActive: member.isActive),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return SAvatar(
      name: member.developer,
      imageUrl: member.avatarUrl?.isNotEmpty == true
          ? member.avatarUrl
          : null,
      size: SAvatarSize.medium,
    );
  }

  Widget _buildInfo(dynamic scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          member.developer,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: member.isActive ? scheme.title : scheme.hint,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        MemberActivityText(
          lastActiveDate: member.lastActiveDate,
        ),
      ],
    );
  }
}
