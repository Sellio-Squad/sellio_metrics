// ─── Data Source: Meetings ───────────────────────────────────────────────────
//
// Removed: fetchAttendance, fetchAnalytics, fetchRateLimitStatus (YAGNI).
// Added: watchMeeting / unwatchMeeting via WebSocket.

import 'package:sellio_metrics/data/models/meeting/meeting_model.dart';
import 'package:sellio_metrics/domain/repositories/meetings_repository.dart';

abstract class MeetingsDataSource {
  Future<MeetingModel> createMeeting(String title);
  Future<List<MeetingModel>> fetchMeetings();
  Future<Map<String, dynamic>> fetchMeetingDetail(String id);
  Future<void> endMeeting(String id);
  Stream<MeetingWsEvent> watchMeeting(String meetingId);
  void unwatchMeeting(String meetingId);
}
