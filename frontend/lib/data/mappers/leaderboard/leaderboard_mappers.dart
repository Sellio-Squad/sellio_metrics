import 'package:sellio_metrics/domain/entities/leaderboard_entry.dart';
import 'package:sellio_metrics/data/models/leaderboard/leaderboard_model.dart';

extension LeaderboardModelMapper on LeaderboardModel {
  LeaderboardEntry toEntity() {
    return LeaderboardEntry(
      developer: developer,
      avatarUrl: avatarUrl,
      prsCreated: prsCreated,
      prsMerged: prsMerged,
      commentsGiven: commentsGiven,
      commitCount: commitCount,
      lineAdditions: lineAdditions,
      lineDeletions: lineDeletions,
      totalScore: totalScore,
    );
  }
}
