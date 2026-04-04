import 'package:sellio_metrics/domain/entities/ticket_entity.dart';

abstract class TicketsRepository {
  Future<List<TicketEntity>> fetchOpenTickets({required String org});
}
