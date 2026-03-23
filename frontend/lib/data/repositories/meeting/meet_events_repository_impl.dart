import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/domain/entities/meet_event_entity.dart';
import 'package:sellio_metrics/domain/repositories/meet_events_repository.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_events_data_source.dart';

@LazySingleton(as: MeetEventsRepository)
class MeetEventsRepositoryImpl implements MeetEventsRepository {
  final MeetEventsDataSource _dataSource;

  MeetEventsRepositoryImpl(this._dataSource);

  @override
  Future<Map<String, dynamic>> subscribe(String spaceName) async {
    return _dataSource.subscribe(spaceName);
  }

  @override
  Future<List<MeetEventEntity>> getEvents({int limit = 50}) async {
    final list = await _dataSource.fetchEvents(limit: limit);
    return list.map((json) => MeetEventEntity.fromJson(json)).toList();
  }

  @override
  Stream<MeetEventEntity> connectStream({String? lastEventId}) {
    return _dataSource
        .connectEventStream(lastEventId: lastEventId)
        .map((json) => MeetEventEntity.fromJson(json));
  }

  @override
  void disconnectStream() {
    _dataSource.disconnectEventStream();
  }

  @override
  Future<List<Map<String, dynamic>>> getSubscriptions() async {
    return _dataSource.fetchSubscriptions();
  }
}
