library;

import 'package:flutter/material.dart';
import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../domain/entities/pr_entity.dart';

class PrTimelineSummary extends StatelessWidget {
  final PrEntity pr;

  const PrTimelineSummary({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final parts = <String>[];

    parts.add('Opened ${formatRelativeTime(pr.openedAt)}');

    if (pr.firstApprovedAt != null) {
      parts.add('1st approval ${formatRelativeTime(pr.firstApprovedAt!)}');
    }
    if (pr.requiredApprovalsMetAt != null) {
      parts.add(
        'All approvals ${formatRelativeTime(pr.requiredApprovalsMetAt!)}',
      );
    }
    if (pr.mergedAt != null) {
      parts.add('Merged ${formatRelativeTime(pr.mergedAt!)}');
    } else if (pr.closedAt != null) {
      parts.add('Closed ${formatRelativeTime(pr.closedAt!)}');
    }

    return Text(
      parts.join(' · '),
      style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
