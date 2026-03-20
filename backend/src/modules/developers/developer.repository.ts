import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";

export interface Member {
    login: string;
    avatarUrl?: string;
    displayName?: string;
    joinedAt?: string;
}

export class DeveloperRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
    ) {
        this.logger = logger.child({ module: "developer-repository" });
    }

    async upsertDeveloper(login: string, avatarUrl?: string, displayName?: string, joinedAt?: string): Promise<void> {
        if (!this.db || !login) return;
        
        await this.db
            .prepare(
                `INSERT INTO members (login, avatar_url, display_name, joined_at)
                 VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(login) DO UPDATE SET
                     avatar_url   = COALESCE(?2, avatar_url),
                     display_name = COALESCE(?3, display_name),
                     joined_at    = COALESCE(?4, joined_at)`
            )
            .bind(login, avatarUrl ?? null, displayName ?? null, joinedAt ?? null)
            .run();
    }

    async getDevelopers(): Promise<Member[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT login, avatar_url, display_name, joined_at FROM members ORDER BY login")
            .all<any>();
            
        return res.results.map((r) => ({
            login:       r.login,
            avatarUrl:   r.avatar_url,
            displayName: r.display_name,
            joinedAt:    r.joined_at,
        }));
    }

    /** Used by members endpoint to compute activity status */
    async getLastActiveDates(): Promise<Record<string, string>> {
        if (!this.db) return {};
        const res = await this.db.prepare(`
            SELECT developer_login, MAX(last_ts) as last_active FROM (
                SELECT author         AS developer_login, MAX(merged_at)    AS last_ts FROM merged_prs      GROUP BY author
                UNION ALL
                SELECT author         AS developer_login, MAX(commented_at) AS last_ts FROM pr_comments      GROUP BY author
                UNION ALL
                SELECT developer_login,                   MAX(joined_at)    AS last_ts FROM meeting_attendance GROUP BY developer_login
            )
            GROUP BY developer_login
        `).all<{ developer_login: string; last_active: string }>();

        const map: Record<string, string> = {};
        for (const row of res.results) map[row.developer_login] = row.last_active;
        return map;
    }
}
