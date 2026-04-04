import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/ticket_entity.dart';
import 'package:sellio_metrics/domain/repositories/tickets_repository.dart';
import 'package:sellio_metrics/data/datasources/tickets/tickets_data_source.dart';

@LazySingleton(as: TicketsRepository)
class TicketsRepositoryImpl implements TicketsRepository {
  final TicketsDataSource _dataSource;

  const TicketsRepositoryImpl(this._dataSource);

  @override
  Future<List<TicketEntity>> fetchOpenTickets({required String org}) async {
    final rawData = await _dataSource.fetchOpenTickets(org: org);
    return rawData
        .map((json) {
          try {
            return TicketEntity.fromJson(json as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<TicketEntity>()
        .toList();
  }
}
