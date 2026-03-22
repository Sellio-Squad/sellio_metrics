import '../../domain/entities/leaderboard_entry.dart';
import '../models/leaderboard_model.dart';

extension LeaderboardModelMapper on LeaderboardModel {
  LeaderboardEntry toEntity() {
    return LeaderboardEntry(
      developer: developer,
      avatarUrl: avatarUrl,
      prsCreated: prsCreated,
      prsMerged: prsMerged,
      commentsGiven: commentsGiven,
      lineAdditions: lineAdditions,
      lineDeletions: lineDeletions,
      totalScore: totalScore,
    );
  }
}
