import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";
import type { MeetingSpace } from "./meetings.types";

export interface DBMeetingSession {
    id:          string;
    spaceName:   string;
    meetingUri?: string;
    meetingCode?: string;
    title?:      string;
    startedAt?:  string;
    endedAt?:    string;
}

export class MeetingsRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
    ) {
        this.logger = logger.child({ module: "meetings-repository" });
    }

    async upsertSession(session: DBMeetingSession): Promise<void> {
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
                session.id, session.spaceName, session.meetingUri ?? null, 
                session.meetingCode ?? null, session.title ?? null, 
                session.startedAt ?? null, session.endedAt ?? null
            )
            .run();
    }

    async getSessions(limit = 50): Promise<DBMeetingSession[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM meeting_sessions ORDER BY created_at DESC LIMIT ?1")
            .bind(limit)
            .all<any>();
            
        return res.results.map((r) => ({
            id:          r.id, 
            spaceName:   r.space_name, 
            meetingUri:  r.meeting_uri,
            meetingCode: r.meeting_code, 
            title:       r.title, 
            startedAt:   r.started_at, 
            endedAt:     r.ended_at,
        }));
    }
}
