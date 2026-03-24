/**
 * Sellio Metrics — D1 Database Service
 *
 * Thin wrapper around Cloudflare D1 for event storage and aggregation.
 *
 * Key design decisions:
 *   - Events store NO points — points derived via JOIN with point_rules
 *   - INSERT OR IGNORE for idempotent event ingestion
 *   - All timestamps stored as UTC ISO 8601
 */

import type { Logger } from "../../core/logger";

export interface PointRule {
    eventType: string;
    points: number;
    description: string | null;
    updatedAt?: string;
}

// ─── D1 Binding Interface ───────────────────────────────────

export interface D1Database {
    prepare(query: string): D1PreparedStatement;
    batch<T = unknown>(statements: D1PreparedStatement[]): Promise<D1Result<T>[]>;
    exec(query: string): Promise<D1ExecResult>;
}

export interface D1PreparedStatement {
    bind(...values: unknown[]): D1PreparedStatement;
    first<T = unknown>(colName?: string): Promise<T | null>;
    run<T = unknown>(): Promise<D1Result<T>>;
    all<T = unknown>(): Promise<D1Result<T>>;
    raw<T = unknown>(): Promise<T[]>;
}

export interface D1Result<T = unknown> {
    results: T[];
    success: boolean;
    meta: { duration: number; changes: number; last_row_id: number };
}

export interface D1ExecResult {
    count: number;
    duration: number;
}

// ─── Service ────────────────────────────────────────────────

export class D1Service {
    private readonly db: D1Database | null;
    private readonly logger: Logger;

    constructor({ d1Database, logger }: { d1Database: D1Database | null; logger: Logger }) {
        this.db = d1Database;
        this.logger = logger.child({ module: "d1" });

        if (!this.db) {
            this.logger.warn("⚠️  No D1 database bound — event storage disabled");
        }
    }

    get isAvailable(): boolean {
        return this.db !== null;
    }

    // ─── Point Rules ────────────────────────────────────────

    async getPointRules(): Promise<PointRule[]> {
        if (!this.db) return [];

        const result = await this.db
            .prepare("SELECT event_type, points, description, updated_at FROM point_rules ORDER BY event_type")
            .all<{ event_type: string; points: number; description: string | null; updated_at: string }>();

        return result.results.map((r) => ({
            eventType: r.event_type,
            points: r.points,
            description: r.description,
            updatedAt: r.updated_at,
        }));
    }

    async setPointRule(eventType: string, points: number, description?: string): Promise<void> {
        if (!this.db) return;

        await this.db
            .prepare(
                `INSERT OR REPLACE INTO point_rules (event_type, points, description, updated_at)
                 VALUES (?1, ?2, COALESCE(?3, (SELECT description FROM point_rules WHERE event_type = ?1)), datetime('now'))`,
            )
            .bind(eventType, points, description || null)
            .run();

        this.logger.info({ eventType, points }, "Point rule updated");
    }

    /** Wipe all sync data (merged PRs + comments). Used by the reset endpoint. */
    async truncateSyncData(): Promise<{ prsDeleted: number; commentsDeleted: number; devsDeleted: number; reposDeleted: number }> {
        if (!this.db) return { prsDeleted: 0, commentsDeleted: 0, devsDeleted: 0, reposDeleted: 0 };

        const [r1, r2, r3, r4] = await this.db.batch([
            this.db.prepare("DELETE FROM pr_comments"),
            this.db.prepare("DELETE FROM merged_prs"),
            this.db.prepare("DELETE FROM repos"),
            // Delete members who have no attendance records to avoid wiping historical Google Meet data (Foreign Key constraint limit)
            this.db.prepare("DELETE FROM members WHERE login NOT IN (SELECT display_name FROM participant_sessions)"),
        ]);

        return {
            commentsDeleted: (r1.meta as any)?.changes ?? 0,
            prsDeleted:      (r2.meta as any)?.changes ?? 0,
            reposDeleted:    (r3.meta as any)?.changes ?? 0,
            devsDeleted:     (r4.meta as any)?.changes ?? 0,
        };
    }

}
