import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";

export interface RelationalLeaderboardEntry {
    developer_login:    string;
    total_points:       number;
    pr_count:           number;
    comment_count:      number;
    commit_count:       number;
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

    async getLeaderboard(since?: string, until?: string, limit = 50, repoIds: number[] = []): Promise<RelationalLeaderboardEntry[]> {
        if (!this.db) return [];

        const prFilter       = since ? `AND mp.merged_at >= '${since}'` : "";
        const cmtFilter      = since ? `AND pc.commented_at >= '${since}'` : "";
        const commitFilter   = since ? `AND c.committed_at >= '${since}'` : "";
        const attendFilter   = since ? `AND ps.start_time >= '${since}'` : "";

        const prUntil        = until ? `AND mp.merged_at <= '${until}'` : "";
        const cmtUntil       = until ? `AND pc.commented_at <= '${until}'` : "";
        const commitUntil    = until ? `AND c.committed_at <= '${until}'` : "";
        const attendUntil    = until ? `AND ps.start_time <= '${until}'` : "";

        // Repo filter — filter directly by integer repo_id (no JOIN needed)
        const safeRepoIds      = Array.isArray(repoIds) ? repoIds.filter((id) => Number.isFinite(id)) : [];
        const hasRepoFilter    = safeRepoIds.length > 0;
        const repoIdList       = safeRepoIds.join(",");
        const prRepoFilter     = hasRepoFilter ? `AND mp.repo_id IN (${repoIdList})` : "";
        const cmtRepoFilter    = hasRepoFilter ? `AND pc.repo_id IN (${repoIdList})` : "";
        const commitRepoFilter = hasRepoFilter ? `AND c.repo_id  IN (${repoIdList})` : "";
        // Note: attendance (participant_sessions) is not linked to repos — no filter applied

        const botFilter = `
            AND %s NOT LIKE '%%[bot]'
            AND %s NOT IN ('Sellio-Bot','sellio-bot','selliobot','SellioBot','github-copilot','dependabot','dependabot-preview','renovate','renovate-bot')
        `;
        const prBot     = botFilter.replace(/%s/g, 'mp.author');
        const cmtBot    = botFilter.replace(/%s/g, 'pc.author');
        const commitBot = botFilter.replace(/%s/g, 'c.author');

        const query = `
            WITH pr_scores AS (
                SELECT
                    mp.author                        AS developer_login,
                    COUNT(*)                         AS pr_count,
                    0                                AS comment_count,
                    0                                AS commit_count,
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
                  ${prBot}
                  ${prFilter} ${prUntil} ${prRepoFilter}
                GROUP BY mp.author
            ),
            comment_scores AS (
                SELECT
                    pc.author                        AS developer_login,
                    0                                AS pr_count,
                    COUNT(*)                         AS comment_count,
                    0                                AS commit_count,
                    0                                AS attendance_minutes,
                    0                                AS line_additions,
                    0                                AS line_deletions,
                    ROUND(COUNT(*) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'PR_COMMENT'), 0), 2) AS points
                FROM pr_comments pc
                WHERE 1=1
                  ${cmtBot}
                  ${cmtFilter} ${cmtUntil} ${cmtRepoFilter}
                GROUP BY pc.author
            ),
            commit_scores AS (
                SELECT
                    c.author                         AS developer_login,
                    0                                AS pr_count,
                    0                                AS comment_count,
                    COUNT(*)                         AS commit_count,
                    0                                AS attendance_minutes,
                    0                                AS line_additions,
                    0                                AS line_deletions,
                    ROUND(COUNT(*) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'COMMIT'), 0), 2) AS points
                FROM commits c
                WHERE 1=1
                  ${commitBot}
                  ${commitFilter} ${commitUntil} ${commitRepoFilter}
                GROUP BY c.author
            ),
            attendance_scores AS (
                SELECT
                    ps.display_name                  AS developer_login,
                    0                                AS pr_count,
                    0                                AS comment_count,
                    0                                AS commit_count,
                    COALESCE(SUM(ROUND((julianday(IFNULL(ps.end_time, datetime('now'))) - julianday(ps.start_time)) * 24 * 60)), 0) AS attendance_minutes,
                    0                                AS line_additions,
                    0                                AS line_deletions,
                    ROUND(COALESCE(SUM(ROUND((julianday(IFNULL(ps.end_time, datetime('now'))) - julianday(ps.start_time)) * 24 * 60)), 0) * COALESCE((SELECT points FROM point_rules WHERE event_type = 'ATTENDANCE_DURATION'), 0), 2) AS points
                FROM participant_sessions ps
                WHERE 1=1 ${attendFilter} ${attendUntil}
                GROUP BY ps.display_name
            )
            SELECT
                developer_login,
                ROUND(SUM(points), 2)            AS total_points,
                SUM(pr_count)                    AS pr_count,
                SUM(comment_count)               AS comment_count,
                SUM(commit_count)                AS commit_count,
                SUM(attendance_minutes)          AS attendance_minutes,
                SUM(line_additions)              AS line_additions,
                SUM(line_deletions)              AS line_deletions
            FROM (
                SELECT * FROM pr_scores
                UNION ALL
                SELECT * FROM comment_scores
                UNION ALL
                SELECT * FROM commit_scores
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


    async deleteDeveloperData(login: string): Promise<{ prs: number; comments: number; commits: number; attendance: number }> {
        if (!this.db) return { prs: 0, comments: 0, commits: 0, attendance: 0 };
        const [r1, r2, r3, r4] = await this.db.batch([
            this.db.prepare("DELETE FROM merged_prs       WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM pr_comments      WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM commits          WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM participant_sessions WHERE display_name = ?1").bind(login),
        ]);
        return { 
            prs:        r1.meta?.changes ?? 0, 
            comments:   r2.meta?.changes ?? 0, 
            commits:    r3.meta?.changes ?? 0,
            attendance: r4.meta?.changes ?? 0 
        };
    }
}
