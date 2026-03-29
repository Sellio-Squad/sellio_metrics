// ─── Domain Entity: Regular Meeting Schedule ──────────────────────────────────
//
// Represents a recurring scheduled meeting (e.g. Daily Standup).
// These are configuration-driven, not fetched from the API.

import 'package:flutter/material.dart';

class RegularMeetingSchedule {
  final String id;
  final String title;
  final String description;
  final String dayTime;
  final String durationLabel;
  final String recurrenceLabel;
  final IconData icon;
  final Color accentColor;
  final DateTime startTime;
  final Duration duration;
  final String recurrenceRule;

  const RegularMeetingSchedule({
    required this.id,
    required this.title,
    required this.description,
    required this.dayTime,
    required this.durationLabel,
    required this.recurrenceLabel,
    required this.icon,
    required this.accentColor,
    required this.startTime,
    required this.duration,
    required this.recurrenceRule,
  });
}
