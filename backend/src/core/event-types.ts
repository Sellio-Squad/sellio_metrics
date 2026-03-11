/**
 * Sellio Metrics — Event-Driven Scoring Types
 *
 * Shared types for the event/scoring system.
 * Points are NOT stored in events — they are derived via JOIN with point_rules.
 */

// ─── Event Types ────────────────────────────────────────────

export const EventType = {
    PR_CREATED: "PR_CREATED",
    PR_MERGED: "PR_MERGED",
    PR_REVIEW: "PR_REVIEW",
    COMMENT: "COMMENT",
    CHECK_IN: "CHECK_IN",
    CHECK_OUT: "CHECK_OUT",
    ATTENDANCE_DURATION: "ATTENDANCE_DURATION",
} as const;

export type EventTypeValue = (typeof EventType)[keyof typeof EventType];

// ─── Scoring Event (no points — derived at query time) ──────

export interface ScoringEvent {
    /** Unique deterministic ID (idempotency key) */
    id: string;
    /** GitHub login or attendance identifier */
    developerId: string;
    /** Type of event */
    eventType: EventTypeValue;
    /** Source system: 'github' | 'attendance' | 'manual' */
    source: "github" | "attendance" | "manual";
    /** Source-specific identifier (e.g. PR URL, meeting ID) */
    sourceId?: string;
    /** ISO 8601 UTC — when the event actually occurred */
    eventTimestamp: string;
    /** JSON-serializable metadata */
    metadata?: Record<string, unknown>;
}

// ─── Point Rule ─────────────────────────────────────────────

export interface PointRule {
    eventType: string;
    points: number;
    description: string | null;
    updatedAt?: string;
}

// ─── Attendance Metadata (enforced standard keys) ───────────

export interface AttendanceMetadata {
    /** ISO 8601 UTC — when the check-in occurred (required for CHECK_IN) */
    checkin_time: string;
    /** ISO 8601 UTC — when the check-out occurred (required for CHECK_OUT) */
    checkout_time?: string;
    /** Computed duration in minutes (set on ATTENDANCE_DURATION events) */
    duration_minutes?: number;
    /** Associated meeting ID */
    meeting_id?: string;
    /** Location or context */
    location?: string;
}

// ─── Leaderboard Entry from D1 aggregation ──────────────────

export interface AggregatedLeaderboardEntry {
    developer_id: string;
    total_points: number;
    event_counts: Record<string, number>;
}

// ─── Rule Change Log Entry ──────────────────────────────────

export interface RuleChangeLogEntry {
    eventType: string;
    oldPoints: number;
    newPoints: number;
    changedAt: string;
}
