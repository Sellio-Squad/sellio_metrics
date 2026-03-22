import 'dart:async';
import '../meet_events_data_source.dart';

class RemoteMeetEventsDataSourceImpl implements MeetEventsDataSource {
  RemoteMeetEventsDataSourceImpl(dynamic dio);

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) => 
    throw UnimplementedError('MeetEvents is only supported on Web');

  @override
  Future<List<Map<String, dynamic>>> fetchEvents({int limit = 50}) => 
    throw UnimplementedError('MeetEvents is only supported on Web');

  @override
  Future<List<Map<String, dynamic>>> fetchSubscriptions() => 
    throw UnimplementedError('MeetEvents is only supported on Web');

  @override
  Stream<Map<String, dynamic>> connectEventStream({String? lastEventId}) => 
    throw UnimplementedError('MeetEvents is only supported on Web');

  @override
  void disconnectEventStream() {}
}
