import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";

export interface RelationalLeaderboardEntry {
    developer_login:    string;
    total_points:       number;
    pr_count:           number;
    comment_count:      number;
    attendance_minutes: number;
    line_additions:     number;
    line_deletions:     number;
}

export class ScoresRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
    ) {
        this.logger = logger.child({ module: "scores-repository" });
    }

    async getLeaderboard(since?: string, until?: string, limit = 50): Promise<RelationalLeaderboardEntry[]> {
        if (!this.db) return [];

        const prFilter     = since ? `AND mp.merged_at >= '${since}'` : "";
        const cmtFilter    = since ? `AND pc.commented_at >= '${since}'` : "";
        const attendFilter = since ? `AND ma.joined_at >= '${since}'` : "";
        
        const prUntil      = until ? `AND mp.merged_at <= '${until}'` : "";
        const cmtUntil     = until ? `AND pc.commented_at <= '${until}'` : "";
        const attendUntil  = until ? `AND ma.joined_at <= '${until}'` : "";

        const query = `
            WITH pr_scores AS (
                SELECT
                    mp.author                        AS developer_login,
                    COUNT(*)                         AS pr_count,
                    0                                AS comment_count,
                    0                                AS attendance_minutes,
                    COALESCE(SUM(mp.additions), 0)   AS line_additions,
                    COALESCE(SUM(mp.deletions), 0)   AS line_deletions,
                    ROUND(
                        COUNT(*) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'PR_MERGED'), 0)
                        + COALESCE(SUM(mp.additions), 0) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'CODE_ADDITION'), 0)
                        + COALESCE(SUM(mp.deletions), 0) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'CODE_DELETION'), 0)
                    , 2) AS points
                FROM merged_prs mp
                WHERE 1=1
                  AND mp.author NOT LIKE '%[bot]'
                  AND mp.author NOT IN ('Sellio-Bot','sellio-bot','github-copilot','dependabot','dependabot-preview','renovate','renovate-bot')
                  ${prFilter} ${prUntil}
                GROUP BY mp.author
            ),
            comment_scores AS (
                SELECT
                    pc.author                        AS developer_login,
                    0                                AS pr_count,
                    COUNT(*)                         AS comment_count,
                    0                                AS attendance_minutes,
                    0                                AS line_additions,
                    0                                AS line_deletions,
                    ROUND(COUNT(*) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'PR_COMMENT'), 0), 2) AS points
                FROM pr_comments pc
                WHERE 1=1
                  AND pc.author NOT LIKE '%[bot]'
                  AND pc.author NOT IN ('Sellio-Bot','sellio-bot','github-copilot','dependabot','dependabot-preview','renovate','renovate-bot')
                  ${cmtFilter} ${cmtUntil}
                GROUP BY pc.author
            ),
            attendance_scores AS (
                SELECT
                    ma.developer_login               AS developer_login,
                    0                                AS pr_count,
                    0                                AS comment_count,
                    COALESCE(SUM(ma.duration_minutes), 0) AS attendance_minutes,
                    0                                AS line_additions,
                    0                                AS line_deletions,
                    ROUND(COALESCE(SUM(ma.duration_minutes), 0) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'ATTENDANCE_DURATION'), 0), 2) AS points
                FROM meeting_attendance ma
                WHERE 1=1 ${attendFilter} ${attendUntil}
                GROUP BY ma.developer_login
            )
            SELECT
                developer_login,
                ROUND(SUM(points), 2)            AS total_points,
                SUM(pr_count)                    AS pr_count,
                SUM(comment_count)               AS comment_count,
                SUM(attendance_minutes)          AS attendance_minutes,
                SUM(line_additions)              AS line_additions,
                SUM(line_deletions)              AS line_deletions
            FROM (
                SELECT * FROM pr_scores
                UNION ALL
                SELECT * FROM comment_scores
                UNION ALL
                SELECT * FROM attendance_scores
            )
            GROUP BY developer_login
            ORDER BY total_points DESC
            LIMIT ?1
        `;

        const res = await this.db.prepare(query).bind(limit).all<RelationalLeaderboardEntry>();
        return res.results;
    }

    async getDeveloperLeaderboardEntry(login: string, since?: string, until?: string): Promise<RelationalLeaderboardEntry | null> {
        const all = await this.getLeaderboard(since, until, 1000);
        return all.find((e) => e.developer_login === login) ?? null;
    }

    async deleteDeveloperData(login: string): Promise<{ prs: number; comments: number; attendance: number }> {
        if (!this.db) return { prs: 0, comments: 0, attendance: 0 };
        const [r1, r2, r3] = await this.db.batch([
            this.db.prepare("DELETE FROM merged_prs       WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM pr_comments      WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM meeting_attendance WHERE developer_login = ?1").bind(login),
        ]);
        return { 
            prs:        r1.meta?.changes ?? 0, 
            comments:   r2.meta?.changes ?? 0, 
            attendance: r3.meta?.changes ?? 0 
        };
    }
}
