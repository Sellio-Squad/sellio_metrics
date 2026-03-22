import 'package:injectable/injectable.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import '../../../../domain/repositories/leaderboard_repository.dart';
import '../../datasources/leaderboard/leaderboard_data_source.dart';
import '../../mappers/leaderboard/leaderboard_mappers.dart';

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
