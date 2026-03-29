// ─── Fake Data Source: Regular Meeting Schedules ──────────────────────────────
//
// In-memory store pre-populated with 4 realistic team meeting schedules.
// Used in dev/test environments. Supports create and delete.

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:sellio_metrics/data/datasources/meeting/regular_meetings_data_source.dart';
import 'package:sellio_metrics/domain/entities/regular_meeting_schedule.dart';

@Injectable(as: RegularMeetingsDataSource, env: [Environment.dev])
class FakeRegularMeetingsDataSource implements RegularMeetingsDataSource {
  // ── Mutable in-memory store
  final List<RegularMeetingSchedule> _store;

  FakeRegularMeetingsDataSource() : _store = _buildDefaults();

  static List<RegularMeetingSchedule> _buildDefaults() {
    final now = DateTime.now();

    DateTime nextDay(int weekday) {
      int diff = weekday - now.weekday;
      if (diff <= 0) diff += 7;
      return now.add(Duration(days: diff));
    }

    final sunday   = nextDay(DateTime.sunday);
    final tuesday  = nextDay(DateTime.tuesday);
    final thursday = nextDay(DateTime.thursday);

    return [
      RegularMeetingSchedule(
        id: 'standup',
        title: 'Daily Standup',
        description: 'Quick sync on blockers and daily progress with the team.',
        dayTime: 'Mon–Fri, 10:00 AM',
        durationLabel: '15 min',
        recurrenceLabel: 'Daily',
        icon: Icons.refresh_rounded,
        accentColor: const Color(0xFF6366F1),
        startTime: DateTime(now.year, now.month, now.day, 10, 0),
        duration: const Duration(minutes: 15),
        recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      ),
      RegularMeetingSchedule(
        id: 'planning',
        title: 'Sprint Planning',
        description: 'Plan tasks and goals for the next sprint cycle with the squad.',
        dayTime: 'Sunday, 11:00 AM',
        durationLabel: '1 hr',
        recurrenceLabel: 'Biweekly',
        icon: Icons.calendar_month_rounded,
        accentColor: const Color(0xFF0EA5E9),
        startTime: DateTime(sunday.year, sunday.month, sunday.day, 11, 0),
        duration: const Duration(hours: 1),
        recurrenceRule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=SU',
      ),
      RegularMeetingSchedule(
        id: 'code_review',
        title: 'Code Review Session',
        description: 'Pair programming and deep-dive code reviews for open PRs.',
        dayTime: 'Tuesday, 2:00 PM',
        durationLabel: '1 hr',
        recurrenceLabel: 'Weekly',
        icon: Icons.code_rounded,
        accentColor: const Color(0xFF10B981),
        startTime: DateTime(tuesday.year, tuesday.month, tuesday.day, 14, 0),
        duration: const Duration(hours: 1),
        recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU',
      ),
      RegularMeetingSchedule(
        id: 'retrospective',
        title: 'Sprint Retrospective',
        description: 'Review what went well and identify improvements for the team.',
        dayTime: 'Thursday, 3:00 PM',
        durationLabel: '45 min',
        recurrenceLabel: 'Biweekly',
        icon: Icons.forum_rounded,
        accentColor: const Color(0xFFF59E0B),
        startTime: DateTime(thursday.year, thursday.month, thursday.day, 15, 0),
        duration: const Duration(minutes: 45),
        recurrenceRule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TH',
      ),
    ];
  }

  @override
  Future<List<RegularMeetingSchedule>> fetchAll() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_store);
  }

  @override
  Future<RegularMeetingSchedule> create(RegularMeetingSchedule schedule) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _store.add(schedule);
    return schedule;
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _store.removeWhere((s) => s.id == id);
  }
}
