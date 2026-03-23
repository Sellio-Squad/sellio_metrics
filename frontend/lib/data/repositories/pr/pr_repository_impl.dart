import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/pr_entity.dart';
import 'package:sellio_metrics/domain/repositories/pr_repository.dart';
import 'package:sellio_metrics/data/datasources/pr/pr_data_source.dart';
import 'package:sellio_metrics/data/mappers/pr/pr_mappers.dart';
import 'package:sellio_metrics/data/models/pr/pr_model.dart';

@LazySingleton(as: PrRepository)
class PrRepositoryImpl implements PrRepository {
  final PrDataSource _remoteDataSource;

  const PrRepositoryImpl(this._remoteDataSource);


  @override
  Future<List<PrEntity>> fetchOpenPrs({required String org}) async {
    final rawData = await _remoteDataSource.fetchOpenPrs(org: org);
    return rawData
        .map((json) {
      try {
        return PrModel.fromJson(json as Map<String, dynamic>).toEntity();
      } catch (e) {
        return null;
      }
    })
        .whereType<PrEntity>()
        .toList();
  }
}
