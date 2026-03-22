import 'dart:async';
import 'package:injectable/injectable.dart';
import '../meeting/meet_events_data_source.dart';

@Injectable(as: MeetEventsDataSource, env: [Environment.dev])
class FakeMeetEventsDataSource implements MeetEventsDataSource {
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _timer;

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) async {
    return {'id': 'sub_${DateTime.now().millisecondsSinceEpoch}'};
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    return [];
  }

  @override
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId}) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _streamController.add({
        'type': 'SPACE_EVENT',
        'data': {'event': 'HEARTBEAT', 'timestamp': DateTime.now().toIso8601String()}
      });
    });
    return _streamController.stream;
  }

  @override
  void disconnectEventStream() {
    _timer?.cancel();
    _streamController.close();
  }
}
