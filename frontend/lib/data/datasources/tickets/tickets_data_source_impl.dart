import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/tickets/tickets_data_source.dart';

@Injectable(as: TicketsDataSource, env: [Environment.prod])
class TicketsDataSourceImpl implements TicketsDataSource {
  final ApiClient _apiClient;

  TicketsDataSourceImpl(this._apiClient);

  @override
  Future<List<dynamic>> fetchOpenTickets({required String org}) async {
    return await _apiClient.get<List<dynamic>>(
      ApiEndpoints.tickets,
      tag: 'open-tickets',
      parser: (data) {
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'] as List<dynamic>;
        }
        return [];
      },
    );
  }
}
