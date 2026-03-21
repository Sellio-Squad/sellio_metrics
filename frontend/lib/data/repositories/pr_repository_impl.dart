library;

import 'package:injectable/injectable.dart';
import '../../domain/entities/pr_entity.dart';
import '../../domain/repositories/pr_repository.dart';
import '../datasources/pr_data_source.dart';

@LazySingleton(as: PrRepository)
class PrRepositoryImpl implements PrRepository {
  final PrDataSource remoteDataSource;

  const PrRepositoryImpl(this.remoteDataSource);


  @override
  Future<List<PrEntity>> fetchOpenPrs({required String org}) async {
    final rawData = await remoteDataSource.fetchOpenPrs(org: org);
    return rawData
        .map((json) {
      try {
        return PrEntity.fromJson(json as Map<String, dynamic>);
      } catch (e) {
        return null;
      }
    })
        .whereType<PrEntity>()
        .toList();
  }
}
