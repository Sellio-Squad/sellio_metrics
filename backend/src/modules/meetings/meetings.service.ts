/**
 * Meetings Service — Google Meet + D1
 *
 * Persists meetings to `meeting_sessions` and attendance to `meeting_attendance`
 * in D1 (instead of the old in-memory KV approach).
 *
 * Flow:
 *   createMeeting()  → Google Meet API createSpace() → D1 upsertMeetingSession()
 *   getAttendance()  → Google Meet API listConferenceRecords/listParticipants
 *                    → D1 upsertMeetingAttendance() (for each participant)
 *                    → returns persisted rows
 *   listMeetings()   → D1 getMeetingSessions()
 *   endMeeting()     → Google Meet API endSpace() → D1 update ended_at
 */

import type { GoogleMeetClient } from "../../infra/google/google-meet.client";
import type { MeetingsRepository } from "./meetings.repository";
import type { AttendanceRepository, MeetingAttendance } from "../attendance/attendance.repository";
import type { Logger } from "../../core/logger";
import type {
    MeetingSpace,
    MeetingDetail,
    AttendanceRecord,
    AttendanceAnalytics,
    RateLimitInfo,
    Participant,
} from "./meetings.types";
import { mapParticipants, aggregateAnalytics } from "./meetings.mapper";

// ─── Service ────────────────────────────────────────────────────

export class MeetingsService {
    private readonly logger: Logger;
    private readonly meetClient: GoogleMeetClient;
    private readonly meetingsRepo: MeetingsRepository;
    private readonly attendanceRepo: AttendanceRepository;

    constructor({
        logger,
        googleMeetClient,
        meetingsRepo,
        attendanceRepo,
    }: {
        logger: Logger;
        googleMeetClient: GoogleMeetClient;
        meetingsRepo: MeetingsRepository;
        attendanceRepo: AttendanceRepository;
    }) {
        this.logger         = logger.child({ module: "meetings" });
        this.meetClient     = googleMeetClient;
        this.meetingsRepo   = meetingsRepo;
        this.attendanceRepo = attendanceRepo;
    }

    // ─── OAuth2 ───────────────────────────────────────────────

    getAuthUrl(): string { return this.meetClient.getAuthUrl(); }

    async authorize(code: string): Promise<any> {
        this.logger.info("Exchanging auth code for tokens…");
        return this.meetClient.authorize(code);
    }

    async isReady(): Promise<boolean> { return this.meetClient.isReady(); }

    async clearCredentials(): Promise<void> { return this.meetClient.clearCredentials(); }

    getRateLimitStatus(): RateLimitInfo { return this.meetClient.getRateLimitStatus(); }

    // ─── Create ───────────────────────────────────────────────

    async createMeeting(title: string): Promise<MeetingSpace> {
        this.logger.info({ title }, "Creating meeting space");

        const space = await this.meetClient.createSpace();
        const id    = `meet_${Date.now()}`;

        await this.meetingsRepo.upsertSession({
            id,
            spaceName:   space.spaceName,
            meetingUri:  space.meetingUri,
            meetingCode: space.meetingCode,
            title,
        });
        this.logger.info({ id, meetingUri: space.meetingUri }, "✅ Meeting created + persisted to D1");

        return { id, title, ...space, createdAt: new Date().toISOString(), participantCount: 0 };
    }

    // ─── List ─────────────────────────────────────────────────

    async listMeetings(limit = 50): Promise<MeetingSpace[]> {
        const sessions = await this.meetingsRepo.getSessions(limit);
        return sessions.map((s) => ({
            id:           s.id,
            title:        s.title ?? s.spaceName,
            spaceName:    s.spaceName,
            meetingUri:   s.meetingUri ?? "",
            meetingCode:  s.meetingCode ?? "",
            createdAt:    s.startedAt ?? "",
            participantCount: 0,
        }));
    }

    // ─── Get Detail ───────────────────────────────────────────

    async getMeeting(id: string): Promise<MeetingDetail> {
        const sessions = await this.meetingsRepo.getSessions(500);
        const session  = sessions.find((s) => s.id === id);
        if (!session) throw new Error(`Meeting not found: ${id}`);

        const attendanceRows = await this.attendanceRepo.getAttendanceForSession(id);

        const participants: Participant[] = attendanceRows.map((a) => ({
            displayName:     a.displayName ?? a.developerLogin,
            email:           a.email ?? null,
            joinedAt:        a.joinedAt,
            leftAt:          a.leftAt ?? null,
            durationMinutes: a.durationMinutes,
            attendanceScore: a.durationMinutes,
        }));

        return {
            id:              session.id,
            title:           session.title ?? session.spaceName,
            spaceName:       session.spaceName,
            meetingUri:      session.meetingUri ?? "",
            meetingCode:     session.meetingCode ?? "",
            createdAt:       session.startedAt ?? "",
            participantCount: participants.length,
            participants,
        };
    }

    // ─── End Meeting ──────────────────────────────────────────

    async endMeeting(id: string): Promise<void> {
        const sessions = await this.meetingsRepo.getSessions(500);
        const session  = sessions.find((s) => s.id === id);
        if (!session) throw new Error(`Meeting not found: ${id}`);

        await this.meetClient.endSpace(session.spaceName);

        // Persist ended_at — reuse upsert since it overwrites on space_name conflict
        await this.meetingsRepo.upsertSession({
            ...session,
            endedAt: new Date().toISOString(),
        });

        this.logger.info({ id, spaceName: session.spaceName }, "Meeting ended");
    }

    // ─── Attendance (sync from Google Meet API → D1) ──────────

    async getAttendance(meetingId: string): Promise<AttendanceRecord> {
        const sessions = await this.meetingsRepo.getSessions(500);
        const session  = sessions.find((s) => s.id === meetingId);
        if (!session) throw new Error(`Meeting not found: ${meetingId}`);

        let participants: Participant[] = [];
        let totalDurationMinutes        = 0;

        try {
            const records = await this.meetClient.listConferenceRecords(session.spaceName);

            // Parallelize API calls using Promise.all
            const participantsResults = await Promise.all(
                records.map(r => this.meetClient.listParticipants(r.name))
            );

            for (let i = 0; i < records.length; i++) {
                const record = records[i];
                const rawParticipants = participantsResults[i];
                const mapped          = mapParticipants(rawParticipants, record.startTime, record.endTime || null);

                // Persist each participant to D1
                for (const p of mapped) {
                    const row: MeetingAttendance = {
                        id:              `${meetingId}:${p.email ?? p.displayName}`,
                        sessionId:       meetingId,
                        developerLogin:  p.email?.split("@")[0] ?? p.displayName,
                        displayName:     p.displayName,
                        email:           p.email ?? undefined,
                        joinedAt:        p.joinedAt ?? record.startTime,
                        leftAt:          p.leftAt ?? undefined,
                        durationMinutes: p.durationMinutes,
                    };
                    await this.attendanceRepo.upsertAttendance(row);
                }

                participants.push(...mapped);

                const start = new Date(record.startTime).getTime();
                const end   = record.endTime ? new Date(record.endTime).getTime() : Date.now();
                totalDurationMinutes += Math.round((end - start) / 60000);
            }
        } catch (e: any) {
            this.logger.warn({ err: e, meetingId }, "Could not fetch live attendance from Google Meet API");
            // Fall back to persisted rows
            const persisted = await this.attendanceRepo.getAttendanceForSession(meetingId);
            participants     = persisted.map((a) => ({
                displayName:     a.displayName ?? a.developerLogin,
                email:           a.email ?? null,
                joinedAt:        a.joinedAt,
                leftAt:          a.leftAt ?? null,
                durationMinutes: a.durationMinutes,
                attendanceScore: a.durationMinutes,
            }));
        }

        // De-duplicate across conference records (same person, multiple sessions)
        const uniqueMap = new Map<string, Participant>();
        for (const p of participants) {
            const key      = p.email ?? p.displayName;
            const existing = uniqueMap.get(key);
            if (!existing || p.durationMinutes > existing.durationMinutes) {
                uniqueMap.set(key, p);
            }
        }

        const deduped = Array.from(uniqueMap.values()).sort((a, b) => b.attendanceScore - a.attendanceScore);

        return {
            meetingId:           session.id,
            meetingTitle:        session.title ?? session.spaceName,
            meetingDate:         session.startedAt ?? "",
            totalDurationMinutes,
            participants: deduped,
        };
    }

    // ─── Analytics ────────────────────────────────────────────

    async getAnalytics(): Promise<AttendanceAnalytics> {
        const sessions = await this.meetingsRepo.getSessions(100);

        const meetingsWithParticipants: Array<{
            id: string; title: string; createdAt: string; participants: Participant[];
        }> = [];

        for (const session of sessions) {
            const rows = await this.attendanceRepo.getAttendanceForSession(session.id);
            meetingsWithParticipants.push({
                id:           session.id,
                title:        session.title ?? session.spaceName,
                createdAt:    session.startedAt ?? "",
                participants: rows.map((a) => ({
                    displayName:     a.displayName ?? a.developerLogin,
                    email:           a.email ?? null,
                    joinedAt:        a.joinedAt,
                    leftAt:          a.leftAt ?? null,
                    durationMinutes: a.durationMinutes,
                    attendanceScore: a.durationMinutes,
                })),
            });
        }

        return aggregateAnalytics(meetingsWithParticipants);
    }
}
