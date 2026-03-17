library;

import 'package:flutter/material.dart';

import '../../../../core/extensions/theme_extensions.dart';
import '../../../../core/theme/app_theme.dart';

class PrDiffStatsChip extends StatelessWidget {
  final int additions;
  final int deletions;
  final int changedFiles;

  const PrDiffStatsChip({
    super.key,
    required this.additions,
    required this.deletions,
    required this.changedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.code, size: 12, color: scheme.hint),
        const SizedBox(width: 3),
        Text(
          '+$additions',
          style: AppTypography.caption.copyWith(
            color: scheme.green,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        Text(
          ' / ',
          style: AppTypography.caption.copyWith(
            color: scheme.hint,
            fontSize: 11,
          ),
        ),
        Text(
          '-$deletions',
          style: AppTypography.caption.copyWith(
            color: scheme.red,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        Text(
          ' ($changedFiles files)',
          style: AppTypography.caption.copyWith(
            color: scheme.body,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
