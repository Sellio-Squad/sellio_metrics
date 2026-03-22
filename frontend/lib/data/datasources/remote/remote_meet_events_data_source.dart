import 'remote_meet_events_web.dart' if (dart.library.io) 'meet_events_stub.dart' as impl;
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import '../meet_events_data_source.dart';

@Injectable(as: MeetEventsDataSource, env: [Environment.prod])
class RemoteMeetEventsDataSource extends impl.RemoteMeetEventsDataSourceImpl {
  RemoteMeetEventsDataSource(Dio dio) : super(dio);
}
