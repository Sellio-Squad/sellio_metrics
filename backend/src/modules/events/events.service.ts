/**
 * Events Module — Service
 *
 * Idempotent event ingestion. Events are pure facts — no points stored.
 * After insert, invalidates the affected developer's KV score cache.
 *
 * All timestamps are normalized to UTC before storage.
 */

import type { D1Service } from "../../infra/database/d1.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { ScoringEvent } from "../../core/event-types";

export class EventsService {
    private readonly d1: D1Service;
    private readonly scoresKv: CacheService;
    private readonly logger: Logger;

    constructor({
        d1Service,
        scoresKvCache,
        logger,
    }: {
        d1Service: D1Service;
        scoresKvCache: CacheService;
        logger: Logger;
    }) {
        this.d1 = d1Service;
        this.scoresKv = scoresKvCache;
        this.logger = logger.child({ module: "events" });
    }

    /**
     * Ingest a scoring event idempotently.
     * Returns { inserted: true } if new, { inserted: false } if duplicate.
     */
    async ingest(event: ScoringEvent): Promise<{ inserted: boolean }> {
        // Normalize timestamp to UTC
        const normalized: ScoringEvent = {
            ...event,
            eventTimestamp: new Date(event.eventTimestamp).toISOString(),
        };

        const inserted = await this.d1.insertEvent(normalized);

        if (inserted) {
            // Invalidate this developer's cached scores
            await this.invalidateDeveloperCache(normalized.developerId);
            this.logger.info(
                { id: normalized.id, dev: normalized.developerId, type: normalized.eventType },
                "Event ingested, cache invalidated",
            );
        }

        return { inserted };
    }

    /**
     * Ingest multiple events (e.g. from a webhook with multiple actions).
     */
    async ingestBatch(events: ScoringEvent[]): Promise<{ inserted: number; duplicates: number }> {
        if (events.length === 0) return { inserted: 0, duplicates: 0 };

        // Normalize timestamps to UTC
        const normalized = events.map((event) => ({
            ...event,
            eventTimestamp: new Date(event.eventTimestamp).toISOString(),
        }));

        const result = await this.d1.insertEventsBatch(normalized);

        if (result.inserted > 0) {
            // Find unique affected developers
            const affectedDevs = new Set(events.map((e) => e.developerId));
            
            // Wait to invalidate caches
            await Promise.all(
                Array.from(affectedDevs).map((devId) => this.invalidateDeveloperCache(devId))
            );
            
            this.logger.info(
                { eventsCount: events.length, inserted: result.inserted, devCount: affectedDevs.size },
                "Batch ingested, caches invalidated",
            );
        }

        return result;
    }

    /**
     * List recent events with optional filters.
     */
    async listEvents(filters: {
        developerId?: string;
        eventType?: string;
        since?: string;
        until?: string;
        limit?: number;
    } = {}): Promise<any[]> {
        return this.d1.queryEvents(filters);
    }

    /**
     * Get real last active dates for all developers from D1.
     */
    async getLastActiveDates(): Promise<Record<string, string>> {
        return this.d1.getLastActiveDates();
    }

    // ─── Private ────────────────────────────────────────────

    /**
     * Invalidate all cached scores for a specific developer.
     * Also invalidates the global leaderboard cache.
     */
    private async invalidateDeveloperCache(developerId: string): Promise<void> {
        try {
            await Promise.all([
                this.scoresKv.del(`score:${developerId}`),
                this.scoresKv.del("leaderboard:all"),
            ]);
        } catch (err: any) {
            this.logger.warn({ err: err.message, developerId }, "Cache invalidation failed (non-critical)");
        }
    }
}
