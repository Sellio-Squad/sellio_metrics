import 'package:flutter/material.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/components/s_avatar.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../../core/l10n/app_localizations.dart';

class LeaderboardRow extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;

  const LeaderboardRow({super.key, required this.index, required this.entry});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final medal = index < 3 ? _medals[index] : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              medal,
              style: TextStyle(
                fontSize: index < 3 ? 18 : 14,
                color: scheme.hint,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SAvatar(
            name: entry.developer,
            imageUrl: entry.avatarUrl?.isNotEmpty == true ? entry.avatarUrl : null,
            size: SAvatarSize.small,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.developer,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.title,
                  ),
                ),
                Text(
                  '${entry.prsCreated} ${l10n.unitPrs} · '
                  '${entry.reviewsGiven} ${l10n.unitReviews} · '
                  '${entry.commentsGiven} ${l10n.unitComments}',
                  style: AppTypography.caption.copyWith(
                    color: scheme.hint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryVariant,
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              '${entry.totalScore}',
              style: AppTypography.caption.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
