import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../design_system/components/s_avatar.dart';

class MemberAvatarSection extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isActive;

  const MemberAvatarSection({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Column(
      children: [
        // Avatar with colored ring
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? const Color(0xFF22C55E).withValues(alpha: 0.5)
                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: SAvatar(
            name: name,
            imageUrl:
                avatarUrl?.isNotEmpty == true ? avatarUrl : null,
            size: SAvatarSize.large,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Developer name
        Text(
          name,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
            color: isActive ? scheme.title : scheme.hint,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
