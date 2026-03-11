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

        let query: string;
        const params: unknown[] = [];
        let paramIdx = 1;

        if (since && until) {
            query = `
                SELECT e.developer_id, SUM(r.points) as total_points
                FROM events e
                JOIN point_rules r ON e.event_type = r.event_type
                WHERE e.event_timestamp BETWEEN ?${paramIdx++} AND ?${paramIdx++}
                GROUP BY e.developer_id
                ORDER BY total_points DESC
                LIMIT ?${paramIdx}
            `;
            params.push(since, until, limit);
        } else if (since) {
            query = `
                SELECT e.developer_id, SUM(r.points) as total_points
                FROM events e
                JOIN point_rules r ON e.event_type = r.event_type
                WHERE e.event_timestamp >= ?${paramIdx++}
                GROUP BY e.developer_id
                ORDER BY total_points DESC
                LIMIT ?${paramIdx}
            `;
            params.push(since, limit);
        } else if (until) {
            query = `
                SELECT e.developer_id, SUM(r.points) as total_points
                FROM events e
                JOIN point_rules r ON e.event_type = r.event_type
                WHERE e.event_timestamp <= ?${paramIdx++}
                GROUP BY e.developer_id
                ORDER BY total_points DESC
                LIMIT ?${paramIdx}
            `;
            params.push(until, limit);
        } else {
            query = `
                SELECT e.developer_id, SUM(r.points) as total_points
                FROM events e
                JOIN point_rules r ON e.event_type = r.event_type
                GROUP BY e.developer_id
                ORDER BY total_points DESC
                LIMIT ?${paramIdx}
            `;
            params.push(limit);
        }

        const result = await this.db.prepare(query).bind(...params).all<{
            developer_id: string;
            total_points: number;
        }>();

        // Also get per-type counts for each developer
        const entries: AggregatedLeaderboardEntry[] = [];
        for (const row of result.results) {
            const countsResult = await this.db
                .prepare(
                    since && until
                        ? `SELECT event_type, COUNT(*) as cnt FROM events WHERE developer_id = ?1 AND event_timestamp BETWEEN ?2 AND ?3 GROUP BY event_type`
                        : since
                          ? `SELECT event_type, COUNT(*) as cnt FROM events WHERE developer_id = ?1 AND event_timestamp >= ?2 GROUP BY event_type`
                          : until
                            ? `SELECT event_type, COUNT(*) as cnt FROM events WHERE developer_id = ?1 AND event_timestamp <= ?2 GROUP BY event_type`
                            : `SELECT event_type, COUNT(*) as cnt FROM events WHERE developer_id = ?1 GROUP BY event_type`,
                )
                .bind(row.developer_id, ...(since ? [since] : []), ...(until && !since ? [until] : until && since ? [until] : []))
                .all<{ event_type: string; cnt: number }>();

            const event_counts: Record<string, number> = {};
            for (const c of countsResult.results) {
                event_counts[c.event_type] = c.cnt;
            }

            entries.push({
                developer_id: row.developer_id,
                total_points: row.total_points,
                event_counts,
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
