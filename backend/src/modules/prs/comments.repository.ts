import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/console-logger";
import type { DeveloperRepository } from "../developers/developer.repository";

export interface PrComment {
    id:          number;
    prId:        number;
    repoId:      number;
    prNumber:    number;
    author:      string;
    body?:       string;
    commentType: "issue" | "review";
    htmlUrl?:    string;
    commentedAt: string;
}

export class CommentsRepository {
    constructor(
        private readonly db: D1Database | null,
        private readonly logger: Logger,
        private readonly developerRepo: DeveloperRepository,
    ) {
        this.logger = logger.child({ module: "comments-repository" });
    }

    async insertComment(comment: PrComment): Promise<boolean> {
        if (!this.db) return false;

        await this.developerRepo.upsertDeveloper(comment.author);

        const result = await this.db
            .prepare(
                `INSERT OR IGNORE INTO pr_comments
                     (id, pr_id, repo_id, pr_number, author, body, comment_type, html_url, commented_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`
            )
            .bind(
                comment.id ?? null, comment.prId ?? null, comment.repoId ?? null, comment.prNumber ?? null, comment.author,
                comment.body ?? null, comment.commentType, comment.htmlUrl ?? null, comment.commentedAt,
            )
            .run();

        return result.meta.changes > 0;
    }

    /**
     * Batch insert comments — single D1 batch() call instead of N+1 queries.
     * Skips duplicates via INSERT OR IGNORE.
     * Returns the number of newly inserted rows.
     */
    async insertCommentBatch(comments: PrComment[]): Promise<number> {
        if (!this.db || comments.length === 0) return 0;

        // D1 batch() executes all statements in a single HTTP round-trip
        const stmts = comments.map((c) =>
            this.db!.prepare(
                `INSERT OR IGNORE INTO pr_comments
                     (id, pr_id, repo_id, pr_number, author, body, comment_type, html_url, commented_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)`,
            ).bind(
                c.id ?? null, c.prId ?? null, c.repoId ?? null, c.prNumber ?? null, c.author,
                c.body ?? null, c.commentType, c.htmlUrl ?? null, c.commentedAt,
            ),
        );

        const results = await this.db.batch(stmts);
        return results.reduce((sum, r) => sum + (r.meta.changes ?? 0), 0);
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
            id:          r.id as number,
            prId:        r.pr_id as number,
            repoId:      r.repo_id as number,
            prNumber:    r.pr_number,
            author:      r.author,
            body:        r.body,
            commentType: r.comment_type,
            htmlUrl:     r.html_url,
            commentedAt: r.commented_at,
        };
    }
}
