import 'package:flutter/material.dart';
import 'package:sellio_metrics/core/theme/app_theme.dart';
import 'package:sellio_metrics/domain/entities/member_status_entity.dart';
import 'package:sellio_metrics/presentation/pages/members/widgets/member_card.dart';

class MembersGrid extends StatelessWidget {
  final List<MemberStatusEntity> members;

  const MembersGrid({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _columns(width);
        final spacing = AppSpacing.md;

        // Calculate card width so we can derive a good aspect ratio
        final totalSpacing = spacing * (crossAxisCount - 1);
        final cardWidth = (width - totalSpacing) / crossAxisCount;

        // Fixed card height — tall enough for avatar + name + badge
        const cardHeight = 200.0;
        final aspectRatio = cardWidth / cardHeight;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => MemberCard(
            member: members[index],
          ),
        );
      },
    );
  }

  int _columns(double width) {
    if (width >= 1100) return 4;
    if (width >= 800) return 3;
    if (width >= 500) return 2;
    return 1;
  }
}
