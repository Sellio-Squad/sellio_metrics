import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/leaderboard_entry.dart';
import 'package:sellio_metrics/domain/repositories/leaderboard_repository.dart';
import 'package:sellio_metrics/data/datasources/leaderboard/leaderboard_data_source.dart';
import 'package:sellio_metrics/data/mappers/leaderboard/leaderboard_mappers.dart';

@LazySingleton(as: LeaderboardRepository)
class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardDataSource _dataSource;

  LeaderboardRepositoryImpl(this._dataSource);

  @override
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final models = await _dataSource.fetchLeaderboard();
    return models.map((m) => m.toEntity()).toList();
  }
}
