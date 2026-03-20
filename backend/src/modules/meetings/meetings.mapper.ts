/**
 * Meetings Module — Mapper (Pure Functions)
 *
 * Transforms raw Google Meet API responses into domain types.
 * Computes attendance duration and scores.
 *
 * Pure functions — no side effects, no I/O.
 */

import type { Participant, AttendanceAnalytics } from "./meetings.types";

// ─── Duration Calculator ────────────────────────────────────

/**
 * Calculate duration in minutes between two ISO timestamps.
 * If endTime is null, uses 'now' as the end.
 */
export function calcDurationMinutes(startTime: string, endTime: string | null): number {
    const start = new Date(startTime).getTime();
    const end = endTime ? new Date(endTime).getTime() : Date.now();

    if (isNaN(start) || isNaN(end)) return 0;

    return Math.max(0, Math.round((end - start) / 60000));
}

// ─── Attendance Score Calculator ────────────────────────────

/**
 * Compute an attendance score (0–100) for a single participant.
 *
 * Weighted formula:
 *   - Presence (40%):  did they show up at all? (binary 0 or 100)
 *   - Duration (35%):  % of meeting time they were present
 *   - Consistency (25%): penalize late joins / early leaves
 */
export function calcAttendanceScore(
    participantJoinTime: string,
    participantLeaveTime: string | null,
    meetingStartTime: string,
    meetingEndTime: string | null,
): number {
    const mStart = new Date(meetingStartTime).getTime();
    const mEnd = meetingEndTime ? new Date(meetingEndTime).getTime() : Date.now();
    const pJoin = new Date(participantJoinTime).getTime();
    const pLeave = participantLeaveTime ? new Date(participantLeaveTime).getTime() : Date.now();

    if (isNaN(mStart) || isNaN(mEnd) || isNaN(pJoin) || isNaN(pLeave)) return 0;

    const meetingDuration = Math.max(1, mEnd - mStart);
    const participantDuration = Math.max(0, Math.min(pLeave, mEnd) - Math.max(pJoin, mStart));

    // Presence: 100 if joined, 0 if not
    const presenceScore = 100;

    // Duration: percentage of meeting time present
    const durationScore = Math.min(100, (participantDuration / meetingDuration) * 100);

    // Consistency: penalize late joins and early leaves
    const lateJoinPenalty = Math.max(0, pJoin - mStart) / meetingDuration;
    const earlyLeavePenalty = Math.max(0, mEnd - pLeave) / meetingDuration;
    const consistencyScore = Math.max(0, 100 - (lateJoinPenalty + earlyLeavePenalty) * 100);

    // Weighted average
    const score = presenceScore * 0.4 + durationScore * 0.35 + consistencyScore * 0.25;

    return Math.round(Math.min(100, Math.max(0, score)));
}

// ─── Map Raw Participants ───────────────────────────────────

/**
 * Transform raw participant data from Google Meet API into domain Participants.
 */
export function mapParticipants(
    rawParticipants: Array<{
        displayName: string;
        email: string | null;
        earliestStartTime: string;
        latestEndTime: string;
    }>,
    meetingStartTime: string,
    meetingEndTime: string | null,
): Participant[] {
    return rawParticipants.map((raw) => ({
        displayName: raw.displayName,
        email: raw.email,
        joinedAt:  raw.earliestStartTime,
        leftAt:    raw.latestEndTime || null,
        durationMinutes: calcDurationMinutes(raw.earliestStartTime, raw.latestEndTime || null),
        attendanceScore: calcAttendanceScore(
            raw.earliestStartTime,
            raw.latestEndTime || null,
            meetingStartTime,
            meetingEndTime,
        ),
    }));
}

// ─── Analytics Aggregation ──────────────────────────────────

/**
 * Aggregate attendance data across multiple meetings into analytics.
 */
export function aggregateAnalytics(
    meetings: Array<{
        id: string;
        title: string;
        createdAt: string;
        participants: Participant[];
    }>,
): AttendanceAnalytics {
    const totalMeetings = meetings.length;

    if (totalMeetings === 0) {
        return {
            totalMeetings: 0,
            totalAttendees: 0,
            averageDurationMinutes: 0,
            averageScore: 0,
            mostActiveParticipants: [],
            attendanceTrends: [],
        };
    }

    // Flatten all participants across all meetings
    const allParticipants = meetings.flatMap((m) => m.participants);
    const totalAttendees = allParticipants.length;

    // Average duration and score
    const averageDurationMinutes =
        totalAttendees > 0
            ? Math.round(allParticipants.reduce((sum, p) => sum + p.durationMinutes, 0) / totalAttendees)
            : 0;
    const averageScore =
        totalAttendees > 0
            ? Math.round(allParticipants.reduce((sum, p) => sum + p.attendanceScore, 0) / totalAttendees)
            : 0;

    // Most active participants (by meeting count and total minutes)
    const participantMap = new Map<string, {
        displayName: string;
        email: string | null;
        meetingsAttended: number;
        totalMinutes: number;
        totalScore: number;
    }>();

    for (const p of allParticipants) {
        const key = p.email ?? p.displayName;
        const existing = participantMap.get(key);
        if (existing) {
            existing.meetingsAttended++;
            existing.totalMinutes += p.durationMinutes;
            existing.totalScore += p.attendanceScore;
        } else {
            participantMap.set(key, {
                displayName: p.displayName,
                email: p.email,
                meetingsAttended: 1,
                totalMinutes: p.durationMinutes,
                totalScore: p.attendanceScore,
            });
        }
    }

    const mostActiveParticipants = Array.from(participantMap.values())
        .map((p) => ({
            displayName: p.displayName,
            email: p.email,
            meetingsAttended: p.meetingsAttended,
            totalMinutes: p.totalMinutes,
            averageScore: Math.round(p.totalScore / p.meetingsAttended),
        }))
        .sort((a, b) => b.meetingsAttended - a.meetingsAttended || b.totalMinutes - a.totalMinutes)
        .slice(0, 10);

    // Attendance trends (grouped by date)
    const trendMap = new Map<string, { attendeeCount: number; totalDuration: number; meetingCount: number }>();
    for (const meeting of meetings) {
        const date = meeting.createdAt.substring(0, 10); // YYYY-MM-DD
        const existing = trendMap.get(date);
        const meetingTotalDuration = meeting.participants.reduce((sum, p) => sum + p.durationMinutes, 0);
        if (existing) {
            existing.attendeeCount += meeting.participants.length;
            existing.totalDuration += meetingTotalDuration;
            existing.meetingCount++;
        } else {
            trendMap.set(date, {
                attendeeCount: meeting.participants.length,
                totalDuration: meetingTotalDuration,
                meetingCount: 1,
            });
        }
    }

    const attendanceTrends = Array.from(trendMap.entries())
        .map(([date, data]) => ({
            date,
            attendeeCount: data.attendeeCount,
            averageDuration: data.meetingCount > 0 ? Math.round(data.totalDuration / data.attendeeCount) : 0,
        }))
        .sort((a, b) => a.date.localeCompare(b.date));

    return {
        totalMeetings,
        totalAttendees,
        averageDurationMinutes,
        averageScore,
        mostActiveParticipants,
        attendanceTrends,
    };
}
