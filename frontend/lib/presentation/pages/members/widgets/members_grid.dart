import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/member_status_entity.dart';
import 'member_card.dart';

class MembersGrid extends StatelessWidget {
  final List<MemberStatusEntity> members;

  const MembersGrid({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _calculateColumns(constraints.maxWidth);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: _aspectRatio(crossAxisCount),
          ),
          itemCount: members.length,
          itemBuilder: (context, index) => MemberCard(
            member: members[index],
          ),
        );
      },
    );
  }

  /// Responsive column calculation.
  int _calculateColumns(double width) {
    if (width >= 900) return 3;
    if (width >= 550) return 2;
    return 1;
  }

  /// Adjust aspect ratio per column count for visual balance.
  double _aspectRatio(int columns) {
    switch (columns) {
      case 3:
        return 2.8;
      case 2:
        return 3.2;
      default:
        return 4.0;
    }
  }
}
