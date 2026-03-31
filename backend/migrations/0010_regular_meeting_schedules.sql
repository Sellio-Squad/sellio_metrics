-- Migration: Regular Meeting Schedules
-- Stores recurring team meeting configurations (e.g. Daily Standup, Sprint Planning).

CREATE TABLE IF NOT EXISTS regular_meeting_schedules (
    id                TEXT PRIMARY KEY,
    title             TEXT NOT NULL,
    description       TEXT NOT NULL DEFAULT '',
    day_time          TEXT NOT NULL,            -- e.g. "Mon–Fri, 10:00 AM"
    duration_label    TEXT NOT NULL,            -- e.g. "15 min"
    recurrence_label  TEXT NOT NULL,            -- e.g. "Daily"
    icon_code         INTEGER NOT NULL,         -- Flutter IconData codePoint (int)
    accent_color      INTEGER NOT NULL,         -- ARGB int e.g. 0xFF6366F1
    start_time        TEXT NOT NULL,            -- ISO 8601 datetime
    duration_minutes  INTEGER NOT NULL,         -- duration in minutes
    recurrence_rule   TEXT NOT NULL,            -- RFC 5545 RRULE string
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
