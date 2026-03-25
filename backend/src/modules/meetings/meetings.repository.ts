import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/logger";
import type { MeetingSessionRow, ParticipantSessionRow } from "./meetings.types";

export class MeetingsRepository {
    private readonly logger: Logger;

    constructor(
        private readonly db: D1Database | null,
        logger: Logger,
    ) {
        this.logger = logger.child({ module: "meetings-repository" });
    }

    // ─── Meeting Sessions ────────────────────────────────────────────────────

    async upsertSession(session: Omit<MeetingSessionRow, "startedAt" | "endedAt"> & Partial<Pick<MeetingSessionRow, "startedAt" | "endedAt">>): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `INSERT INTO meeting_sessions (id, space_name, meeting_uri, meeting_code, title, started_at, ended_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(space_name) DO UPDATE SET
                     title      = COALESCE(?5, title),
                     started_at = COALESCE(?6, started_at),
                     ended_at   = COALESCE(?7, ended_at)`
            )
            .bind(
                session.id, session.spaceName, session.meetingUri,
                session.meetingCode, session.title,
                session.startedAt ?? null, session.endedAt ?? null,
            )
            .run();
    }

    async getSessions(limit = 50): Promise<MeetingSessionRow[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM meeting_sessions ORDER BY created_at DESC LIMIT ?1")
            .bind(limit)
            .all<any>();
        return res.results.map(this.rowToSession);
    }

    async getSessionById(id: string): Promise<MeetingSessionRow | null> {
        if (!this.db) return null;
        const row = await this.db
            .prepare("SELECT * FROM meeting_sessions WHERE id = ?1 LIMIT 1")
            .bind(id)
            .first<any>();
        return row ? this.rowToSession(row) : null;
    }

    async getSessionBySpaceName(spaceName: string): Promise<MeetingSessionRow | null> {
        if (!this.db) return null;
        const row = await this.db
            .prepare("SELECT * FROM meeting_sessions WHERE space_name = ?1 LIMIT 1")
            .bind(spaceName)
            .first<any>();
        return row ? this.rowToSession(row) : null;
    }

    async getActiveParticipantCounts(): Promise<Record<string, number>> {
        if (!this.db) return {};
        const res = await this.db.prepare(
            `SELECT session_id, COUNT(*) as c 
             FROM participant_sessions 
             WHERE end_time IS NULL 
             GROUP BY session_id`
        ).all<{ session_id: string; c: number }>();

        const counts: Record<string, number> = {};
        for (const r of res.results) counts[r.session_id] = r.c;
        return counts;
    }
    private rowToSession = (r: any): MeetingSessionRow => {
        return {
            id:          r.id,
            spaceName:   r.space_name,
            meetingUri:  r.meeting_uri  ?? "",
            meetingCode: r.meeting_code ?? "",
            title:       r.title        ?? r.space_name,
            startedAt:   r.started_at   ?? null,
            endedAt:     r.ended_at     ?? null,
        };
    }

    // ─── Participant Sessions ────────────────────────────────────────────────

    async insertParticipantJoin(row: ParticipantSessionRow): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `INSERT INTO participant_sessions
                     (id, session_id, participant_key, display_name, start_time, end_time)
                 VALUES (?1, ?2, ?3, ?4, ?5, NULL)
                 ON CONFLICT(id) DO NOTHING`
            )
            .bind(row.id, row.sessionId, row.participantKey, row.displayName, row.startTime)
            .run();
    }

    /**
     * Sets end_time on the most recent active row for this participant.
     * Uses a subquery because SQLite does not support ORDER BY / LIMIT in UPDATE.
     */
    async markParticipantLeft(sessionId: string, participantKey: string, endTime: string): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `UPDATE participant_sessions
                 SET end_time = ?3
                 WHERE id = (
                     SELECT id FROM participant_sessions
                     WHERE session_id = ?1
                       AND participant_key = ?2
                       AND end_time IS NULL
                     ORDER BY start_time DESC
                     LIMIT 1
                 )`
            )
            .bind(sessionId, participantKey, endTime)
            .run();
    }

    /** Close ALL open sessions when the meeting itself ends. */
    async closeAllParticipantSessions(sessionId: string, endTime: string): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `UPDATE participant_sessions
                 SET end_time = ?2
                 WHERE session_id = ?1 AND end_time IS NULL`
            )
            .bind(sessionId, endTime)
            .run();
    }

    async getActiveParticipants(sessionId: string): Promise<ParticipantSessionRow[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare(
                `SELECT * FROM participant_sessions
                 WHERE session_id = ?1 AND end_time IS NULL
                 ORDER BY start_time ASC`
            )
            .bind(sessionId)
            .all<any>();
        return res.results.map(this.rowToParticipant);
    }

    async getAllParticipants(sessionId: string): Promise<ParticipantSessionRow[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare(
                `SELECT * FROM participant_sessions
                 WHERE session_id = ?1
                 ORDER BY start_time ASC`
            )
            .bind(sessionId)
            .all<any>();
        return res.results.map(this.rowToParticipant);
    }

    private rowToParticipant = (r: any): ParticipantSessionRow => {
        return {
            id:              r.id,
            sessionId:       r.session_id,
            participantKey:  r.participant_key,
            displayName:     r.display_name,
            startTime:       r.start_time ?? null,
            endTime:         r.end_time   ?? null,
        };
    }
}
