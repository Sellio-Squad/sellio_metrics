// ─── Real Data Source: Regular Meeting Schedules ───────────────────────────────
//
// Fetches schedules from the backend REST API:
//   GET    /api/meetings/schedules          → list
//   POST   /api/meetings/schedules          → create
//   DELETE /api/meetings/schedules/:id      → delete

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/core/network/api_client.dart';
import 'package:sellio_metrics/core/network/api_endpoints.dart';
import 'package:sellio_metrics/data/datasources/meeting/regular_meetings_data_source.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';

@Injectable(as: RegularMeetingsDataSource, env: [Environment.prod])
class RegularMeetingsDataSourceImpl implements RegularMeetingsDataSource {
  final ApiClient _apiClient;

  RegularMeetingsDataSourceImpl(this._apiClient);

  // ─── Interface ───────────────────────────────────────────────────────────

  @override
  Future<List<RegularMeetingSchedule>> fetchAll() async {
    final data = await _apiClient.get<List<dynamic>>(ApiEndpoints.meetingSchedules);
    return data
        .cast<Map<String, dynamic>>()
        .map(_fromJson)
        .toList();
  }

  @override
  Future<RegularMeetingSchedule> create(RegularMeetingSchedule schedule) async {
    final data = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.meetingSchedules,
      data: _toJson(schedule),
    );
    return _fromJson(data);
  }

  @override
  Future<void> delete(String id) async {
    await _apiClient.delete(ApiEndpoints.meetingScheduleById(id));
  }

  // ─── Serialisation ────────────────────────────────────────────────────────

  RegularMeetingSchedule _fromJson(Map<String, dynamic> json) {
    final durationMinutes = (json['durationMinutes'] as int?) ?? 60;
    final iconCode        = (json['iconCode']        as int?) ?? Icons.calendar_today.codePoint;
    final accentColorInt  = (json['accentColor']     as int?) ?? 0xFF6366F1;

    return RegularMeetingSchedule(
      id:               json['id']              as String,
      title:            json['title']           as String,
      description:      json['description']     as String? ?? '',
      dayTime:          json['dayTime']          as String,
      durationLabel:    json['durationLabel']    as String,
      recurrenceLabel:  json['recurrenceLabel']  as String,
      icon:             _getIconFromCode(iconCode),
      accentColor:      Color(accentColorInt),
      startTime:        DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      duration:         Duration(minutes: durationMinutes),
      recurrenceRule:   json['recurrenceRule']   as String,
    );
  }

  IconData _getIconFromCode(int codePoint) {
    const availableIcons = [
      Icons.groups_rounded,
      Icons.refresh_rounded,
      Icons.calendar_month_rounded,
      Icons.code_rounded,
      Icons.forum_rounded,
      Icons.rocket_launch_rounded,
      Icons.lightbulb_rounded,
      Icons.analytics_rounded,
      Icons.bug_report_rounded,
      Icons.school_rounded,
      Icons.calendar_today,
    ];
    
    for (final icon in availableIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    return Icons.calendar_today;
  }

  Map<String, dynamic> _toJson(RegularMeetingSchedule s) => {
    'id':               s.id,
    'title':            s.title,
    'description':      s.description,
    'dayTime':          s.dayTime,
    'durationLabel':    s.durationLabel,
    'recurrenceLabel':  s.recurrenceLabel,
    'iconCode':         s.icon.codePoint,
    'accentColor':      s.accentColor.toARGB32(),
    'startTime':        s.startTime.toIso8601String(),
    'durationMinutes':  s.duration.inMinutes,
    'recurrenceRule':   s.recurrenceRule,
  };
}
