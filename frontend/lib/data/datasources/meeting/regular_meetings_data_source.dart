// ─── Data Source: Regular Meeting Schedules (interface) ───────────────────────

import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';

abstract class RegularMeetingsDataSource {
  Future<List<RegularMeetingSchedule>> fetchAll();
  Future<RegularMeetingSchedule> create(RegularMeetingSchedule schedule);
  Future<void> delete(String id);
}
