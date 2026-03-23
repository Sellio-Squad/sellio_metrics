import 'package:sellio_metrics/data/datasources/meeting/meet_events_data_source.dart';
import 'package:sellio_metrics/data/datasources/meeting/meet_events_data_source_web.dart' if (dart.library.io) 'meet_events_stub.dart' as impl;
import 'package:injectable/injectable.dart';

@Injectable(as: MeetEventsDataSource, env: [Environment.prod])
class MeetEventsDataSourceImpl extends impl.MeetEventsDataSourcePlatformImpl {
  MeetEventsDataSourceImpl(super.apiClient);
}
