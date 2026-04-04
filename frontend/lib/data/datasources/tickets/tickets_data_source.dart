abstract class TicketsDataSource {
  Future<List<dynamic>> fetchOpenTickets({required String org});
}
