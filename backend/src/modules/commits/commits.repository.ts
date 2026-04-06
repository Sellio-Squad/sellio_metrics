import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/logger";
import type { DeveloperRepository } from "../developers/developer.repository";

export interface Commit {
    sha:         string;
    repoId:      number;
    author:      string;
    message?:    string;
    branch?:     string;
    committedAt: string;
    htmlUrl?:    string;
    additions?:  number;
    deletions?:  number;
}

export class CommitsRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
        private readonly developerRepo: DeveloperRepository,
    ) {
        this.logger = logger.child({ module: "commits-repository" });
    }

    /**
     * Insert a single commit. Idempotent via SHA primary key (INSERT OR IGNORE).
     */
    async insertCommit(commit: Commit): Promise<boolean> {
        if (!this.db) return false;

        await this.developerRepo.upsertDeveloper(commit.author);

        const result = await this.db
            .prepare(
                `INSERT OR IGNORE INTO commits
                     (sha, repo_id, author, message, branch, committed_at, html_url, additions, deletions)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`
            )
            .bind(
                commit.sha, commit.repoId, commit.author,
                commit.message ?? null, commit.branch ?? null,
                commit.committedAt, commit.htmlUrl ?? null,
                commit.additions ?? 0, commit.deletions ?? 0,
            )
            .run();

        return result.meta.changes > 0;
    }

    /**
     * Batch insert commits — single D1 batch() call.
     * Skips duplicates via INSERT OR IGNORE on SHA.
     * Returns the number of newly inserted rows.
     */
    async insertCommitBatch(commits: Commit[]): Promise<number> {
        if (!this.db || commits.length === 0) return 0;

        // Batch upsert all unique authors — single D1 .batch() round-trip
        const logins = [...new Set(commits.map((c) => c.author))];
        await this.developerRepo.upsertDeveloperBatch(logins.map((login) => ({ login })));

        let totalInserted = 0;

        // D1 batch has a limit, process in chunks of 50
        for (let i = 0; i < commits.length; i += 50) {
            const chunk = commits.slice(i, i + 50);

            const stmts = chunk.map((c) =>
                this.db!.prepare(
                    `INSERT OR IGNORE INTO commits
                         (sha, repo_id, author, message, branch, committed_at, html_url, additions, deletions)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`
                ).bind(
                    c.sha, c.repoId, c.author,
                    c.message ?? null, c.branch ?? null,
                    c.committedAt, c.htmlUrl ?? null,
                    c.additions ?? 0, c.deletions ?? 0,
                ),
            );

            const results = await this.db.batch(stmts);
            totalInserted += results.reduce((sum, r) => sum + (r.meta.changes ?? 0), 0);
        }

        return totalInserted;
    }

    /**
     * Get commits with optional filters.
     */
    async getCommits(filters: {
        author?: string;
        repoId?: number;
        branch?: string;
        since?: string;
        limit?: number;
    } = {}): Promise<Commit[]> {
        if (!this.db) return [];

        const conditions: string[] = [];
        const params: unknown[] = [];
        let p = 1;

        if (filters.author) { conditions.push(`author = ?${p++}`);        params.push(filters.author); }
        if (filters.repoId) { conditions.push(`repo_id = ?${p++}`);       params.push(filters.repoId); }
        if (filters.branch) { conditions.push(`branch = ?${p++}`);        params.push(filters.branch); }
        if (filters.since)  { conditions.push(`committed_at >= ?${p++}`); params.push(filters.since); }

        const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
        const limit = filters.limit ?? 100;

        const res = await this.db
            .prepare(`SELECT * FROM commits ${where} ORDER BY committed_at DESC LIMIT ?${p}`)
            .bind(...params, limit)
            .all<any>();

        return res.results.map((r) => ({
            sha:         r.sha as string,
            repoId:      r.repo_id as number,
            author:      r.author as string,
            message:     r.message,
            branch:      r.branch,
            committedAt: r.committed_at,
            htmlUrl:     r.html_url,
            additions:   r.additions ?? 0,
            deletions:   r.deletions ?? 0,
        }));
    }

    /** Get the set of commit SHAs already stored for a repo — used to skip re-processing. */
    async getExistingShas(repoId: number): Promise<Set<string>> {
        if (!this.db) return new Set();
        const rows = await this.db.prepare(
            "SELECT sha FROM commits WHERE repo_id = ?1"
        ).bind(repoId).all<{ sha: string }>();
        return new Set(rows.results.map((r) => r.sha));
    }

    /**
     * Get the most recent commit timestamp for a repo.
     * Used to drive incremental sync — only fetch commits newer than this date.
     * Returns undefined if no commits are stored yet (triggers full historical fetch).
     */
    async getLatestCommittedAt(repoId: number): Promise<string | undefined> {
        if (!this.db) return undefined;
        const row = await this.db
            .prepare("SELECT MAX(committed_at) AS latest FROM commits WHERE repo_id = ?1")
            .bind(repoId)
            .first<{ latest: string | null }>();
        return row?.latest ?? undefined;
    }
}
