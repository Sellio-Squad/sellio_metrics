import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../design_system/components/s_avatar.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import 'package:sellio_metrics/l10n/app_localizations.dart';

class LeaderboardRow extends StatelessWidget {
  final int index;
  final LeaderboardEntry entry;

  const LeaderboardRow({super.key, required this.index, required this.entry});

  static const _medals = ['🥇', '🥈', '🥉'];
  static final _fmt = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l10n = AppLocalizations.of(context);
    final medal = index < 3 ? _medals[index] : '${index + 1}';

    final additions = entry.lineAdditions;
    final deletions = entry.lineDeletions;

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
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${entry.prsCreated} ${l10n.unitPrs} · '
                      '${entry.commentsGiven} ${l10n.unitComments}',
                      style: AppTypography.caption.copyWith(
                        color: scheme.hint,
                        fontSize: 11,
                      ),
                    ),
                    if (additions > 0 || deletions > 0) ...[
                      Text(
                        ' · ',
                        style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
                      ),
                      Text(
                        '+${_fmt.format(additions)}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.green.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' / ',
                        style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
                      ),
                      Text(
                        '-${_fmt.format(deletions)}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.red.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' ${l10n.unitLines}',
                        style: AppTypography.caption.copyWith(color: scheme.hint, fontSize: 11),
                      ),
                    ],
                  ],
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
              entry.totalScore.toStringAsFixed(0),
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
