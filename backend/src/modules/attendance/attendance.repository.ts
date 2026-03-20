import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";

export interface MeetingAttendance {
    id: string;
    sessionId: string;
    developerLogin: string;
    displayName?: string;
    email?: string;
    joinedAt: string;
    leftAt?: string;
    durationMinutes: number;
}

export class AttendanceRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
    ) {
        this.logger = logger.child({ module: "attendance-repository" });
    }

    async upsertAttendance(record: MeetingAttendance): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `INSERT INTO meeting_attendance
                     (id, session_id, developer_login, display_name, email, joined_at, left_at, duration_minutes)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
                 ON CONFLICT(session_id, developer_login) DO UPDATE SET
                     left_at          = COALESCE(?7, left_at),
                     duration_minutes = MAX(duration_minutes, ?8),
                     display_name     = COALESCE(?4, display_name),
                     email            = COALESCE(?5, email)`
            )
            .bind(
                record.id, record.sessionId, record.developerLogin,
                record.displayName ?? null, record.email ?? null,
                record.joinedAt, record.leftAt ?? null, record.durationMinutes
            )
            .run();
    }

    /** DB-level filtering to avoid N+1 query loops in the service layer */
    async queryAttendance(filters: {
        developerLogin?: string;
        since?: string;
        until?: string;
        limit?: number;
    }): Promise<MeetingAttendance[]> {
        if (!this.db) return [];

        const conditions: string[] = ["1=1"];
        const binds: any[] = [];
        let bindIndex = 1;

        if (filters.developerLogin) {
            conditions.push(`developer_login = ?${bindIndex++}`);
            binds.push(filters.developerLogin);
        }
        if (filters.since) {
            conditions.push(`joined_at >= ?${bindIndex++}`);
            binds.push(filters.since);
        }
        if (filters.until) {
            conditions.push(`joined_at <= ?${bindIndex++}`);
            binds.push(filters.until);
        }

        const limit = filters.limit ?? 50;

        const sql = `
            SELECT * FROM meeting_attendance
            WHERE ${conditions.join(" AND ")}
            ORDER BY joined_at DESC
            LIMIT ?${bindIndex}
        `;
        binds.push(limit);

        const res = await this.db.prepare(sql).bind(...binds).all<any>();

        return res.results.map((r) => ({
            id:              r.id,
            sessionId:       r.session_id,
            developerLogin:  r.developer_login,
            displayName:     r.display_name,
            email:           r.email,
            joinedAt:        r.joined_at,
            leftAt:          r.left_at,
            durationMinutes: r.duration_minutes,
        }));
    }

    async getAttendanceForSession(sessionId: string): Promise<MeetingAttendance[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM meeting_attendance WHERE session_id = ?1 ORDER BY joined_at")
            .bind(sessionId).all<any>();
            
        return res.results.map((r) => ({
            id:              r.id,
            sessionId:       r.session_id,
            developerLogin:  r.developer_login,
            displayName:     r.display_name,
            email:           r.email,
            joinedAt:        r.joined_at,
            leftAt:          r.left_at,
            durationMinutes: r.duration_minutes,
        }));
    }
}
