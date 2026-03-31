/**
 * Regular Meeting Schedules — Types
 *
 * DB row and API shapes for recurring team meeting configurations.
 */

// ─── DB Row ─────────────────────────────────────────────────────────────────

export interface RegularMeetingScheduleRow {
    id:               string;
    title:            string;
    description:      string;
    day_time:         string;
    duration_label:   string;
    recurrence_label: string;
    icon_code:        number;   // Flutter IconData codePoint
    accent_color:     number;   // ARGB int
    start_time:       string;   // ISO 8601
    duration_minutes: number;
    recurrence_rule:  string;   // RFC 5545 RRULE
    created_at:       string;
}

// ─── API Shapes ──────────────────────────────────────────────────────────────

export interface RegularMeetingScheduleResponse {
    id:               string;
    title:            string;
    description:      string;
    dayTime:          string;
    durationLabel:    string;
    recurrenceLabel:  string;
    iconCode:         number;
    accentColor:      number;
    startTime:        string;
    durationMinutes:  number;
    recurrenceRule:   string;
}

export interface CreateRegularMeetingScheduleBody {
    id?:              string;
    title:            string;
    description?:     string;
    dayTime:          string;
    durationLabel:    string;
    recurrenceLabel:  string;
    iconCode:         number;
    accentColor:      number;
    startTime:        string;
    durationMinutes:  number;
    recurrenceRule:   string;
}
