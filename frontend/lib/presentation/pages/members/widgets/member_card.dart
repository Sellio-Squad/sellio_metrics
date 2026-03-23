import 'package:flutter/material.dart';

import 'package:sellio_metrics/core/extensions/theme_extensions.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/domain/entities/member_status_entity.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/member_avatar_section.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/member_status_indicator.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/member_activity_text.dart';

class MemberCard extends StatelessWidget {
  final MemberStatusEntity member;

  const MemberCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: scheme.stroke,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Status indicator + label — top right
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: MemberStatusIndicator(
              isActive: member.isActive,
            ),
          ),

          // Card content — centered
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MemberAvatarSection(
                    name: member.developer,
                    avatarUrl: member.avatarUrl,
                    isActive: member.isActive,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  MemberActivityText(
                    lastActiveDate: member.lastActiveDate,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}