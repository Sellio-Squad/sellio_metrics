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
import type { ScoringEvent, PointRule, AggregatedLeaderboardEntry } from "../../core/event-types";

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

    // ─── Event Ingestion (Idempotent) ───────────────────────

    /**
     * Insert an event. Returns true if inserted, false if duplicate (idempotent).
     * Uses INSERT OR IGNORE to prevent duplicate events from webhook retries.
     */
    async insertEvent(event: ScoringEvent): Promise<boolean> {
        if (!this.db) return false;

        try {
            const result = await this.db
                .prepare(
                    `INSERT OR IGNORE INTO events (id, developer_id, event_type, source, source_id, event_timestamp, metadata)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
                )
                .bind(
                    event.id,
                    event.developerId,
                    event.eventType,
                    event.source,
                    event.sourceId || null,
                    event.eventTimestamp,
                    event.metadata ? JSON.stringify(event.metadata) : null,
                )
                .run();

            const inserted = result.meta.changes > 0;

            if (inserted) {
                this.logger.info({ eventId: event.id, type: event.eventType }, "Event inserted");
            } else {
                this.logger.info({ eventId: event.id }, "Duplicate event ignored (idempotent)");
            }

            return inserted;
        } catch (err: any) {
            this.logger.error({ err: err.message, eventId: event.id }, "Failed to insert event");
            throw err;
        }
    }

    /**
     * Insert multiple events using D1's batch API to avoid subrequest limits.
     * Processes in chunks of 50.
     */
    async insertEventsBatch(events: ScoringEvent[]): Promise<{ inserted: number; duplicates: number }> {
        if (!this.db || events.length === 0) return { inserted: 0, duplicates: 0 };

        let totalInserted = 0;
        let totalDuplicates = 0;

        const statement = this.db.prepare(
            `INSERT OR IGNORE INTO events (id, developer_id, event_type, source, source_id, event_timestamp, metadata)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)`,
        );

        // Max D1 batch limit is 100 statements. We use 50 to be safe.
        for (let i = 0; i < events.length; i += 50) {
            const chunk = events.slice(i, i + 50);
            const stmts = chunk.map((event) =>
                statement.bind(
                    event.id,
                    event.developerId,
                    event.eventType,
                    event.source,
                    event.sourceId || null,
                    event.eventTimestamp,
                    event.metadata ? JSON.stringify(event.metadata) : null,
                ),
            );

            try {
                const results = await this.db.batch(stmts);
                let chunkInserted = 0;
                for (const res of results) {
                    chunkInserted += res.meta.changes || 0;
                }
                totalInserted += chunkInserted;
                totalDuplicates += chunk.length - chunkInserted;
            } catch (err: any) {
                this.logger.error({ err: err.message, chunk_size: chunk.length }, "Failed to execute batch insert");
                throw err;
            }
        }

        return { inserted: totalInserted, duplicates: totalDuplicates };
    }

    // ─── Event Queries ──────────────────────────────────────

    /**
     * Query events with optional filters.
     */
    async queryEvents(filters: {
        developerId?: string;
        eventType?: string;
        since?: string;
        until?: string;
        limit?: number;
    }): Promise<any[]> {
        if (!this.db) return [];

        const conditions: string[] = [];
        const params: unknown[] = [];
        let paramIdx = 1;

        if (filters.developerId) {
            conditions.push(`developer_id = ?${paramIdx++}`);
            params.push(filters.developerId);
        }
        if (filters.eventType) {
            conditions.push(`event_type = ?${paramIdx++}`);
            params.push(filters.eventType);
        }
        if (filters.since) {
            conditions.push(`event_timestamp >= ?${paramIdx++}`);
            params.push(filters.since);
        }
        if (filters.until) {
            conditions.push(`event_timestamp <= ?${paramIdx++}`);
            params.push(filters.until);
        }

        const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";
        const limit = filters.limit || 100;

        const result = await this.db
            .prepare(
                `SELECT id, developer_id, event_type, source, source_id, event_timestamp, created_at, metadata
                 FROM events ${where}
                 ORDER BY event_timestamp DESC
                 LIMIT ?${paramIdx}`,
            )
            .bind(...params, limit)
            .all();

        return result.results;
    }

    /**
     * Get the most recent event timestamp for all developers.
     */
    async getLastActiveDates(): Promise<Record<string, string>> {
        if (!this.db) return {};

        const result = await this.db.prepare(
            `SELECT developer_id, MAX(event_timestamp) as last_active
             FROM events
             GROUP BY developer_id`
        ).all();

        const map: Record<string, string> = {};
        for (const row of result.results) {
            const r = row as any;
            map[r.developer_id as string] = r.last_active as string;
        }
        return map;
    }

    // ─── Leaderboard Aggregation ────────────────────────────

    /**
     * Compute leaderboard by JOINing events with point_rules.
     * Points are derived dynamically — changing rules auto-reflects.
     */
    async getLeaderboard(
        since?: string,
        until?: string,
        limit = 10,
    ): Promise<AggregatedLeaderboardEntry[]> {
        if (!this.db) return [];

        const conditions: string[] = [];
        const params: unknown[] = [];
        let paramIdx = 1;

        if (since) {
            conditions.push(`e.event_timestamp >= ?${paramIdx++}`);
            params.push(since);
        }
        if (until) {
            conditions.push(`e.event_timestamp <= ?${paramIdx++}`);
            params.push(until);
        }
        const where = conditions.length > 0 ? `WHERE ${conditions.join(" AND ")}` : "";

        // Main query: total points per developer
        // For CODE_ADDITION / CODE_DELETION the `lines` metadata field is the
        // per-event multiplier so the score = rule.points × lines_changed
        const query = `
            SELECT
                e.developer_id,
                ROUND(SUM(
                    r.points * COALESCE(CAST(json_extract(e.metadata, '$.lines') AS REAL), 1.0)
                ), 2) AS total_points
            FROM events e
            JOIN point_rules r ON e.event_type = r.event_type
            ${where}
            GROUP BY e.developer_id
            ORDER BY total_points DESC
            LIMIT ?${paramIdx}
        `;
        params.push(limit);

        const result = await this.db.prepare(query).bind(...params).all<{
            developer_id: string;
            total_points: number;
        }>();

        // For each developer also fetch per-type counts and line sums
        const entries: AggregatedLeaderboardEntry[] = [];
        for (const row of result.results) {
            const countConditions: string[] = [`developer_id = ?1`];
            const countParams: unknown[] = [row.developer_id];
            let ci = 2;
            if (since) { countConditions.push(`event_timestamp >= ?${ci++}`); countParams.push(since); }
            if (until) { countConditions.push(`event_timestamp <= ?${ci++}`); countParams.push(until); }
            const countWhere = `WHERE ${countConditions.join(" AND ")}`;

            const countsResult = await this.db
                .prepare(`SELECT event_type, COUNT(*) as cnt FROM events ${countWhere} GROUP BY event_type`)
                .bind(...countParams)
                .all<{ event_type: string; cnt: number }>();

            const event_counts: Record<string, number> = {};
            for (const c of countsResult.results) {
                event_counts[c.event_type] = c.cnt;
            }

            // Sum of actual lines added/deleted (from `lines` metadata)
            const linesResult = await this.db
                .prepare(`
                    SELECT
                        event_type,
                        CAST(ROUND(SUM(COALESCE(CAST(json_extract(metadata, '$.lines') AS REAL), 0))) AS INTEGER) as total_lines
                    FROM events
                    ${countWhere}
                    AND event_type IN ('CODE_ADDITION', 'CODE_DELETION')
                    GROUP BY event_type
                `)
                .bind(...countParams)
                .all<{ event_type: string; total_lines: number }>();

            let line_additions = 0;
            let line_deletions = 0;
            for (const lr of linesResult.results) {
                if (lr.event_type === "CODE_ADDITION") line_additions = lr.total_lines ?? 0;
                if (lr.event_type === "CODE_DELETION") line_deletions = lr.total_lines ?? 0;
            }

            entries.push({
                developer_id: row.developer_id,
                total_points: row.total_points,
                event_counts,
                line_additions,
                line_deletions,
            });
        }

        return entries;
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

    /**
     * Delete all events for a given developer (e.g. to remove test accounts).
     */
    async deleteEventsByDeveloper(developerId: string): Promise<number> {
        if (!this.db) return 0;

        const result = await this.db
            .prepare("DELETE FROM events WHERE developer_id = ?1")
            .bind(developerId)
            .run();

        const deleted = result.meta.changes ?? 0;
        this.logger.info({ developerId, deleted }, "Deleted all events for developer");
        return deleted;
    }

    // ─── Latest CHECK_IN for a developer ────────────────────

    async getLatestCheckIn(developerId: string): Promise<any | null> {
        if (!this.db) return null;

        return this.db
            .prepare(
                `SELECT id, developer_id, event_type, event_timestamp, metadata
                 FROM events
                 WHERE developer_id = ?1 AND event_type = 'CHECK_IN'
                 ORDER BY event_timestamp DESC
                 LIMIT 1`,
            )
            .bind(developerId)
            .first();
    }

    // ─── Archiving ──────────────────────────────────────────

    /**
     * Move events older than the given date to the archive table.
     */
    async archiveOldEvents(beforeDate: string): Promise<number> {
        if (!this.db) return 0;

        const result = await this.db.batch([
            this.db.prepare(
                `INSERT INTO events_archive (id, developer_id, event_type, source, source_id, event_timestamp, created_at, metadata)
                 SELECT id, developer_id, event_type, source, source_id, event_timestamp, created_at, metadata
                 FROM events
                 WHERE event_timestamp < ?1`,
            ).bind(beforeDate),
            this.db.prepare("DELETE FROM events WHERE event_timestamp < ?1").bind(beforeDate),
        ]);

        const archived = result[1]?.meta?.changes || 0;
        this.logger.info({ beforeDate, archived }, "Events archived");
        return archived;
    }
}
