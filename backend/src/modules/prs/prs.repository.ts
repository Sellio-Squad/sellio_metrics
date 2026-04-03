import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";
import type { DeveloperRepository } from "../developers/developer.repository";

export interface MergedPr {
    id:           number;
    repoId:       number;
    prNumber:     number;
    author:       string;
    title?:       string;
    body?:        string;
    htmlUrl?:     string;
    mergedAt:     string;
    prCreatedAt?: string;
    additions:    number | null;
    deletions:    number | null;
}

export class PrsRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
        private readonly developerRepo: DeveloperRepository,
    ) {
        this.logger = logger.child({ module: "prs-repository" });
    }

    async upsertMergedPr(pr: MergedPr): Promise<boolean> {
        if (!this.db) return false;
        
        await this.developerRepo.upsertDeveloper(pr.author);

        const result = await this.db
            .prepare(
                `INSERT INTO merged_prs
                     (id, repo_id, pr_number, author, title, body, html_url, merged_at, pr_created_at, additions, deletions)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
                 ON CONFLICT(repo_id, pr_number) DO UPDATE SET
                     additions     = ?10,
                     deletions     = ?11,
                     title         = COALESCE(?5, title),
                     body          = COALESCE(?6, body),
                     pr_created_at = COALESCE(?9, pr_created_at)`
            )
            .bind(
                pr.id, pr.repoId, pr.prNumber, pr.author,
                pr.title ?? null, pr.body ?? null, pr.htmlUrl ?? null, pr.mergedAt,
                pr.prCreatedAt ?? null, pr.additions, pr.deletions,
            )
            .run();

        return result.meta.changes > 0;
    }

    async upsertMergedPrBatch(prs: MergedPr[]): Promise<{ inserted: number; updated: number }> {
        if (!this.db || prs.length === 0) return { inserted: 0, updated: 0 };

        // Batch upsert all unique authors — single D1 .batch() round-trip
        const logins = [...new Set(prs.map((p) => p.author))];
        await this.developerRepo.upsertDeveloperBatch(logins.map((login) => ({ login })));

        // Step 1: INSERT OR IGNORE — meta.changes counts ONLY truly new rows
        const insertStmt = this.db.prepare(
            `INSERT OR IGNORE INTO merged_prs
                 (id, repo_id, pr_number, author, title, body, html_url, merged_at, pr_created_at, additions, deletions)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)`
        );

        // Step 2: UPDATE fields that may have changed (e.g. additions/deletions corrected by GitHub)
        const updateStmt = this.db.prepare(
            `UPDATE merged_prs SET
                 additions     = ?1,
                 deletions     = ?2,
                 title         = COALESCE(?3, title),
                 body          = COALESCE(?4, body),
                 pr_created_at = COALESCE(?5, pr_created_at)
             WHERE repo_id = ?6 AND pr_number = ?7`
        );

        let inserted = 0;
        let updated  = 0;

        for (let i = 0; i < prs.length; i += 50) {
            const chunk = prs.slice(i, i + 50);

            const insertResults = await this.db.batch(
                chunk.map((pr) => insertStmt.bind(
                    pr.id, pr.repoId, pr.prNumber, pr.author,
                    pr.title ?? null, pr.body ?? null, pr.htmlUrl ?? null, pr.mergedAt,
                    pr.prCreatedAt ?? null, pr.additions, pr.deletions,
                )),
            );
            const chunkInserted = insertResults.reduce((sum, r) => sum + (r.meta.changes || 0), 0);
            inserted += chunkInserted;

            // Only UPDATE existing rows (those that were ignored above)
            const existingChunk = chunk.filter((_, idx) => (insertResults[idx].meta.changes || 0) === 0);
            if (existingChunk.length > 0) {
                const updateResults = await this.db.batch(
                    existingChunk.map((pr) => updateStmt.bind(
                        pr.additions, pr.deletions,
                        pr.title ?? null, pr.body ?? null, pr.prCreatedAt ?? null,
                        pr.repoId, pr.prNumber,
                    )),
                );
                updated += updateResults.reduce((sum, r) => sum + (r.meta.changes || 0), 0);
            }
        }

        return { inserted, updated };
    }

    /** Get the set of PR numbers already stored for a repo — used to skip re-processing unchanged PRs. */
    async getExistingPrNumbers(repoId: number): Promise<Set<number>> {
        if (!this.db) return new Set();
        const rows = await this.db.prepare(
            "SELECT pr_number FROM merged_prs WHERE repo_id = ?1"
        ).bind(repoId).all<{ pr_number: number }>();
        return new Set(rows.results.map((r) => r.pr_number));
    }

    async getMergedPrs(filters: { author?: string; repoId?: number; since?: string; limit?: number } = {}): Promise<MergedPr[]> {
        if (!this.db) return [];
        
        const conditions: string[] = [];
        const params: unknown[] = [];
        let p = 1;
        
        if (filters.author) { conditions.push(`author = ?${p++}`);   params.push(filters.author); }
        if (filters.repoId) { conditions.push(`repo_id = ?${p++}`);  params.push(filters.repoId); }
        if (filters.since)  { conditions.push(`merged_at >= ?${p++}`); params.push(filters.since); }

        const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
        const limit = filters.limit ?? 100;
        
        const res = await this.db
            .prepare(`SELECT * FROM merged_prs ${where} ORDER BY merged_at DESC LIMIT ?${p}`)
            .bind(...params, limit)
            .all<any>();

        return res.results.map((r) => ({
            id:          r.id as number,
            repoId:      r.repo_id as number,
            prNumber:    r.pr_number,
            author:      r.author,
            title:       r.title,
            body:        r.body,
            htmlUrl:     r.html_url,
            mergedAt:    r.merged_at,
            prCreatedAt: r.pr_created_at,
            additions:   r.additions,
            deletions:   r.deletions,
        }));
    }
}
