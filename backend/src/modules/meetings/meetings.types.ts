/**
 * Meetings Module — Domain Types
 *
 * Shared types for the meetings feature.
 * Used by the service, mapper, and route layers.
 */

// ─── Meeting Space ──────────────────────────────────────────

export interface MeetingSpace {
    /** Internal tracking ID (auto-generated). */
    id: string;
    /** Human-readable meeting title. */
    title: string;
    /** Google Meet space resource name (e.g. "spaces/abc123"). */
    spaceName: string;
    /** The joinable meeting URI (e.g. "https://meet.google.com/abc-defg-hij"). */
    meetingUri: string;
    /** Short meeting code (e.g. "abc-defg-hij"). */
    meetingCode: string;
    /** ISO timestamp when the meeting was created. */
    createdAt: string;
    /** Current participant count (live). */
    participantCount: number;
}

// ─── Participant ────────────────────────────────────────────

export interface Participant {
    /** Display name from Google Meet. */
    displayName: string;
    /** Email address (if available). */
    email: string | null;
    /** ISO timestamp when participant first joined. */
    joinedAt: string;
    /** ISO timestamp when participant left (null if still in meeting). */
    leftAt: string | null;
    /** Duration in minutes spent in the meeting. */
    durationMinutes: number;
    /** Attendance score (0–100), computed on backend. */
    attendanceScore: number;
}

// ─── Participant Session (raw join/leave event) ─────────────

export interface ParticipantSession {
    displayName: string;
    email: string | null;
    startTime: string;
    endTime: string | null;
}

// ─── Attendance Record ──────────────────────────────────────

export interface AttendanceRecord {
    meetingId: string;
    meetingTitle: string;
    meetingDate: string;
    totalDurationMinutes: number;
    participants: Participant[];
}

// ─── Attendance Analytics ───────────────────────────────────

export interface AttendanceAnalytics {
    totalMeetings: number;
    totalAttendees: number;
    averageDurationMinutes: number;
    averageScore: number;
    mostActiveParticipants: Array<{
        displayName: string;
        email: string | null;
        meetingsAttended: number;
        totalMinutes: number;
        averageScore: number;
    }>;
    attendanceTrends: Array<{
        date: string;
        attendeeCount: number;
        averageDuration: number;
    }>;
}

// ─── Rate Limit Info ────────────────────────────────────────

export interface RateLimitInfo {
    remaining: number;
    limit: number;
    resetAt: string;
    isLow: boolean;
}

// ─── Meeting Detail (meeting + participants) ────────────────

export interface MeetingDetail extends MeetingSpace {
    participants: Participant[];
}

// ─── Create Meeting Request ─────────────────────────────────

export interface CreateMeetingRequest {
    title: string;
}
