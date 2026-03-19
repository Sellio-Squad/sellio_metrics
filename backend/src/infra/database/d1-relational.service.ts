/**
 * Sellio Metrics — D1 Relational Service
 *
 * Handles CRUD on the normalized relational tables:
 *   repos, developers, merged_prs, pr_comments,
 *   meeting_sessions, meeting_attendance
 *
 * Leaderboard uses UNION ALL across domain tables, scored
 * dynamically via point_rules. No event table involved.
 */

import type { Logger } from "../../core/logger";
import type { D1Database } from "./d1.service";

// ─── Domain Types ────────────────────────────────────────────

export interface Repo {
    id: string;        // "{owner}/{name}"
    owner: string;
    name: string;
    htmlUrl?: string;
    description?: string;
    githubCreatedAt?: string;
    pushedAt?: string;
}

export interface Developer {
    login: string;
    avatarUrl?: string;
    displayName?: string;
    joinedAt?: string;
}

export interface MergedPr {
    id: string;        // "github:pr:{repo_id}:{pr_number}"
    repoId: string;    // FK → repos.id
    prNumber: number;
    author: string;    // FK → developers.login
    title?: string;
    htmlUrl?: string;
    mergedAt: string;
    prCreatedAt?: string; // GitHub PR opened date
    additions: number;
    deletions: number;
}

export interface PrComment {
    id: string;        // "github:comment:{repo_id}:{comment_id}"
    prId: string;      // FK → merged_prs.id
    repoId: string;    // FK → repos.id
    prNumber: number;
    author: string;    // FK → developers.login
    body?: string;
    commentType: "issue" | "review";
    htmlUrl?: string;
    commentedAt: string;
}

export interface MeetingSession {
    id: string;
    spaceName: string;
    meetingUri?: string;
    meetingCode?: string;
    title?: string;
    startedAt?: string;
    endedAt?: string;
}

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

export interface RelationalLeaderboardEntry {
    developer_login: string;
    total_points: number;
    pr_count: number;
    comment_count: number;
    attendance_minutes: number;
    line_additions: number;
    line_deletions: number;
}

// ─── Service ─────────────────────────────────────────────────

export class D1RelationalService {
    private readonly db: D1Database | null;
    private readonly logger: Logger;

    constructor({ d1Database, logger }: { d1Database: D1Database | null; logger: Logger }) {
        this.db = d1Database;
        this.logger = logger.child({ module: "d1-relational" });
    }

    get isAvailable(): boolean { return this.db !== null; }

    // ─── Repo Registry ───────────────────────────────────────

    /**
     * Ensure a repo exists. Idempotent — safe to call before every PR insert.
     * Returns the repo id ("{owner}/{name}").
     */
    async upsertRepo(
        owner: string,
        name: string,
        opts: { htmlUrl?: string; description?: string; githubCreatedAt?: string; pushedAt?: string } = {},
    ): Promise<string> {
        if (!this.db) return `${owner}/${name}`;
        const id = `${owner}/${name}`;
        await this.db
            .prepare(
                `INSERT INTO repos (id, owner, name, html_url, description, github_created_at, pushed_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(owner, name) DO UPDATE SET
                     html_url         = COALESCE(?4, html_url),
                     description      = COALESCE(?5, description),
                     github_created_at = COALESCE(?6, github_created_at),
                     pushed_at        = COALESCE(?7, pushed_at)`,
            )
            .bind(id, owner, name,
                opts.htmlUrl ?? null, opts.description ?? null,
                opts.githubCreatedAt ?? null, opts.pushedAt ?? null)
            .run();
        return id;
    }

    async listRepos(): Promise<Repo[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT id, owner, name, html_url, description FROM repos ORDER BY owner, name")
            .all<any>();
        return res.results.map((r) => ({
            id: r.id, owner: r.owner, name: r.name,
            htmlUrl: r.html_url, description: r.description,
        }));
    }

    // ─── Developer Registry ──────────────────────────────────

    async upsertDeveloper(login: string, avatarUrl?: string, displayName?: string, joinedAt?: string): Promise<void> {
        if (!this.db || !login) return;
        // Bots are always filtered before calling this; we never store them.
        await this.db
            .prepare(
                `INSERT INTO developers (login, avatar_url, display_name, joined_at)
                 VALUES (?1, ?2, ?3, ?4)
                 ON CONFLICT(login) DO UPDATE SET
                     avatar_url   = COALESCE(?2, avatar_url),
                     display_name = COALESCE(?3, display_name),
                     joined_at    = COALESCE(?4, joined_at)`,
            )
            .bind(login, avatarUrl ?? null, displayName ?? null, joinedAt ?? null)
            .run();
    }

    async getDevelopers(): Promise<Developer[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT login, avatar_url, display_name, joined_at FROM developers ORDER BY login")
            .all<any>();
        return res.results.map((r) => ({
            login: r.login, avatarUrl: r.avatar_url,
            displayName: r.display_name, joinedAt: r.joined_at,
        }));
    }

    /** Used by the members endpoint — checks all domain tables for last activity */
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

    // ─── Merged PRs ──────────────────────────────────────────

    async upsertMergedPr(pr: MergedPr): Promise<boolean> {
        if (!this.db) return false;
        await this.upsertDeveloper(pr.author);

        const result = await this.db
            .prepare(
                `INSERT INTO merged_prs (id, repo_id, pr_number, author, title, html_url, merged_at, pr_created_at, additions, deletions)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                 ON CONFLICT(repo_id, pr_number) DO UPDATE SET
                     additions    = ?9,
                     deletions    = ?10,
                     title        = COALESCE(?5, title),
                     pr_created_at = COALESCE(?8, pr_created_at)`,
            )
            .bind(pr.id, pr.repoId, pr.prNumber, pr.author, pr.title ?? null, pr.htmlUrl ?? null, pr.mergedAt, pr.prCreatedAt ?? null, pr.additions, pr.deletions)
            .run();

        return result.meta.changes > 0;
    }

    async upsertMergedPrBatch(prs: MergedPr[]): Promise<{ upserted: number }> {
        if (!this.db || prs.length === 0) return { upserted: 0 };

        const logins = [...new Set(prs.map((p) => p.author))];
        for (const login of logins) await this.upsertDeveloper(login);

        const stmt = this.db.prepare(
            `INSERT INTO merged_prs (id, repo_id, pr_number, author, title, html_url, merged_at, pr_created_at, additions, deletions)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
             ON CONFLICT(repo_id, pr_number) DO UPDATE SET
                 additions    = ?9,
                 deletions    = ?10,
                 title        = COALESCE(?5, title),
                 pr_created_at = COALESCE(?8, pr_created_at)`,
        );

        let total = 0;
        for (let i = 0; i < prs.length; i += 50) {
            const chunk = prs.slice(i, i + 50);
            const results = await this.db.batch(
                chunk.map((pr) => stmt.bind(pr.id, pr.repoId, pr.prNumber, pr.author, pr.title ?? null, pr.htmlUrl ?? null, pr.mergedAt, pr.prCreatedAt ?? null, pr.additions, pr.deletions)),
            );
            total += results.reduce((sum, r) => sum + (r.meta.changes || 0), 0);
        }
        return { upserted: total };
    }

    async getMergedPrs(filters: { author?: string; repoId?: string; since?: string; limit?: number } = {}): Promise<MergedPr[]> {
        if (!this.db) return [];
        const conditions: string[] = [];
        const params: unknown[] = [];
        let p = 1;
        if (filters.author) { conditions.push(`author = ?${p++}`);   params.push(filters.author); }
        if (filters.repoId) { conditions.push(`repo_id = ?${p++}`);  params.push(filters.repoId); }
        if (filters.since)  { conditions.push(`merged_at >= ?${p++}`); params.push(filters.since); }

        const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
        const res = await this.db
            .prepare(`SELECT * FROM merged_prs ${where} ORDER BY merged_at DESC LIMIT ?${p}`)
            .bind(...params, filters.limit ?? 100)
            .all<any>();

        return res.results.map((r) => ({
            id: r.id, repoId: r.repo_id, prNumber: r.pr_number, author: r.author,
            title: r.title, htmlUrl: r.html_url, mergedAt: r.merged_at,
            additions: r.additions, deletions: r.deletions,
        }));
    }

    // ─── PR Comments ─────────────────────────────────────────

    /**
     * Insert a comment row. Uses INSERT OR IGNORE — idempotent via comment id.
     * Skips silently if the parent PR does not exist yet (unmerged PR).
     */
    async insertComment(comment: PrComment): Promise<boolean> {
        if (!this.db) return false;

        const prExists = await this.db
            .prepare("SELECT id FROM merged_prs WHERE id = ?1")
            .bind(comment.prId)
            .first<{ id: string }>();

        if (!prExists) {
            this.logger.info({ prId: comment.prId, author: comment.author }, "Comment skipped — PR not merged yet");
            return false;
        }

        await this.upsertDeveloper(comment.author);

        const result = await this.db
            .prepare(
                `INSERT OR IGNORE INTO pr_comments
                     (id, pr_id, repo_id, pr_number, author, body, comment_type, html_url, commented_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`,
            )
            .bind(
                comment.id, comment.prId, comment.repoId, comment.prNumber, comment.author,
                comment.body ?? null, comment.commentType, comment.htmlUrl ?? null, comment.commentedAt,
            )
            .run();

        return result.meta.changes > 0;
    }

    async getCommentsByPr(prId: string): Promise<PrComment[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM pr_comments WHERE pr_id = ?1 ORDER BY commented_at")
            .bind(prId)
            .all<any>();
        return res.results.map(this.mapComment);
    }

    async getCommentsByAuthor(author: string, limit = 50): Promise<PrComment[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM pr_comments WHERE author = ?1 ORDER BY commented_at DESC LIMIT ?2")
            .bind(author, limit)
            .all<any>();
        return res.results.map(this.mapComment);
    }

    private mapComment(r: any): PrComment {
        return {
            id: r.id, prId: r.pr_id, repoId: r.repo_id, prNumber: r.pr_number,
            author: r.author, body: r.body, commentType: r.comment_type,
            htmlUrl: r.html_url, commentedAt: r.commented_at,
        };
    }

    // ─── Meeting Sessions ────────────────────────────────────

    async upsertMeetingSession(session: MeetingSession): Promise<void> {
        if (!this.db) return;
        await this.db
            .prepare(
                `INSERT INTO meeting_sessions (id, space_name, meeting_uri, meeting_code, title, started_at, ended_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
                 ON CONFLICT(space_name) DO UPDATE SET
                     title = COALESCE(?5, title), started_at = COALESCE(?6, started_at), ended_at = COALESCE(?7, ended_at)`,
            )
            .bind(session.id, session.spaceName, session.meetingUri ?? null, session.meetingCode ?? null, session.title ?? null, session.startedAt ?? null, session.endedAt ?? null)
            .run();
    }

    async getMeetingSessions(limit = 50): Promise<MeetingSession[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM meeting_sessions ORDER BY created_at DESC LIMIT ?1")
            .bind(limit)
            .all<any>();
        return res.results.map((r) => ({
            id: r.id, spaceName: r.space_name, meetingUri: r.meeting_uri,
            meetingCode: r.meeting_code, title: r.title, startedAt: r.started_at, endedAt: r.ended_at,
        }));
    }

    // ─── Meeting Attendance ──────────────────────────────────

    async upsertMeetingAttendance(record: MeetingAttendance): Promise<void> {
        if (!this.db) return;
        await this.upsertDeveloper(record.developerLogin);
        await this.db
            .prepare(
                `INSERT INTO meeting_attendance
                     (id, session_id, developer_login, display_name, email, joined_at, left_at, duration_minutes)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
                 ON CONFLICT(session_id, developer_login) DO UPDATE SET
                     left_at          = COALESCE(?7, left_at),
                     duration_minutes = MAX(duration_minutes, ?8),
                     display_name     = COALESCE(?4, display_name),
                     email            = COALESCE(?5, email)`,
            )
            .bind(record.id, record.sessionId, record.developerLogin, record.displayName ?? null, record.email ?? null, record.joinedAt, record.leftAt ?? null, record.durationMinutes)
            .run();
    }

    async getAttendanceForSession(sessionId: string): Promise<MeetingAttendance[]> {
        if (!this.db) return [];
        const res = await this.db
            .prepare("SELECT * FROM meeting_attendance WHERE session_id = ?1 ORDER BY joined_at")
            .bind(sessionId).all<any>();
        return res.results.map((r) => ({
            id: r.id, sessionId: r.session_id, developerLogin: r.developer_login,
            displayName: r.display_name, email: r.email, joinedAt: r.joined_at,
            leftAt: r.left_at, durationMinutes: r.duration_minutes,
        }));
    }

    // ─── Leaderboard (UNION ALL across all domain tables) ───

    /**
     * UNION ALL leaderboard query — dynamically scored via point_rules.
     *
     * PR_MERGED    → 1 point per merge (flat)
     * CODE_ADDITION / CODE_DELETION → points × lines (from merged_prs columns)
     * PR_COMMENT   → points per comment row (COUNT from pr_comments)
     * ATTENDANCE_DURATION → points per minute (from meeting_attendance)
     */
    async getLeaderboard(since?: string, until?: string, limit = 50): Promise<RelationalLeaderboardEntry[]> {
        if (!this.db) return [];

        // Build date filter fragments per table
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
                WHERE 1=1 ${prFilter} ${prUntil}
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
                WHERE 1=1 ${cmtFilter} ${cmtUntil}
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
                SUM(pr_count)                     AS pr_count,
                SUM(comment_count)                AS comment_count,
                SUM(attendance_minutes)           AS attendance_minutes,
                SUM(line_additions)               AS line_additions,
                SUM(line_deletions)               AS line_deletions
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

    /** Single developer lookup — used for incremental snapshot patching */
    async getDeveloperLeaderboardEntry(login: string, since?: string, until?: string): Promise<RelationalLeaderboardEntry | null> {
        const all = await this.getLeaderboard(since, until, 1000);
        return all.find((e) => e.developer_login === login) ?? null;
    }

    /** Admin cleanup — removes all records for a developer */
    async deleteDeveloperData(login: string): Promise<{ prs: number; comments: number; attendance: number }> {
        if (!this.db) return { prs: 0, comments: 0, attendance: 0 };
        const [r1, r2, r3] = await this.db.batch([
            this.db.prepare("DELETE FROM merged_prs       WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM pr_comments      WHERE author           = ?1").bind(login),
            this.db.prepare("DELETE FROM meeting_attendance WHERE developer_login = ?1").bind(login),
        ]);
        return { prs: r1.meta.changes ?? 0, comments: r2.meta.changes ?? 0, attendance: r3.meta.changes ?? 0 };
    }
}
