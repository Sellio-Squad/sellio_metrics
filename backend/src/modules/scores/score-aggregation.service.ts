/**
 * Scores Module — Score Aggregation Service
 *
 * On-demand leaderboard aggregation from D1 (events JOIN point_rules).
 * Results cached in SCORES_KV for fast reads.
 *
 * Features:
 *   - Per-developer mutex (KV lock) to prevent concurrent recalculation
 *   - Periodic precomputed snapshots via Cron Trigger
 *   - Targeted cache invalidation per developer
 */

import type { D1Service } from "../../infra/database/d1.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { AggregatedLeaderboardEntry } from "../../core/event-types";

/** Cache TTL for leaderboard results (6 hours — refreshed by cron) */
const LEADERBOARD_CACHE_TTL = 6 * 60 * 60;
/** Lock TTL — 30 seconds max */
const LOCK_TTL = 30;

export interface LeaderboardResult {
    entries: AggregatedLeaderboardEntry[];
    cachedAt: string;
    since: string | null;
    until: string | null;
}

export class ScoreAggregationService {
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
        this.logger = logger.child({ module: "score-aggregation" });
    }

    /**
     * Get leaderboard — checks KV cache first, falls back to D1 aggregation.
     */
    async getLeaderboard(
        since?: string,
        until?: string,
        limit = 10,
    ): Promise<LeaderboardResult> {
        const cacheKey = this.leaderboardCacheKey(since, until);

        // Check cache first
        const cached = await this.scoresKv.get<LeaderboardResult>(cacheKey);
        if (cached?.data) {
            this.logger.info("Leaderboard served from cache");
            return cached.data;
        }

        // Cache miss — compute from D1 with lock
        return this.computeAndCacheLeaderboard(cacheKey, since, until, limit);
    }

    /**
     * Get score for a single developer.
     */
    async getDeveloperScore(
        developerId: string,
        since?: string,
        until?: string,
    ): Promise<{ developerId: string; totalPoints: number; eventCounts: Record<string, number> } | null> {
        const cacheKey = `score:${developerId}:${since || "all"}:${until || "all"}`;

        const cached = await this.scoresKv.get<any>(cacheKey);
        if (cached?.data) return cached.data;

        // Compute from D1
        const entries = await this.d1.getLeaderboard(since, until, 1000);
        const entry = entries.find((e) => e.developer_id === developerId);
        if (!entry) return null;

        const result = {
            developerId: entry.developer_id,
            totalPoints: entry.total_points,
            eventCounts: entry.event_counts,
        };

        await this.scoresKv.set(cacheKey, result, LEADERBOARD_CACHE_TTL);
        return result;
    }

    /**
     * Precompute leaderboard snapshots (called by Cron Trigger).
     * Stores "all-time", current month, and current week snapshots.
     */
    async precomputeSnapshots(): Promise<void> {
        this.logger.info("Precomputing leaderboard snapshots (cron)");

        const now = new Date();

        // All-time
        const allTime = await this.d1.getLeaderboard(undefined, undefined, 50);
        await this.scoresKv.set(
            this.leaderboardCacheKey(),
            { entries: allTime, cachedAt: now.toISOString(), since: null, until: null },
            LEADERBOARD_CACHE_TTL,
        );

        // Current month
        const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
        const monthEntries = await this.d1.getLeaderboard(monthStart, undefined, 50);
        await this.scoresKv.set(
            this.leaderboardCacheKey(monthStart),
            { entries: monthEntries, cachedAt: now.toISOString(), since: monthStart, until: null },
            LEADERBOARD_CACHE_TTL,
        );

        // Current week (Monday-based)
        const dayOfWeek = now.getUTCDay();
        const mondayOffset = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - mondayOffset));
        const weekStartIso = weekStart.toISOString();
        const weekEntries = await this.d1.getLeaderboard(weekStartIso, undefined, 50);
        await this.scoresKv.set(
            this.leaderboardCacheKey(weekStartIso),
            { entries: weekEntries, cachedAt: now.toISOString(), since: weekStartIso, until: null },
            LEADERBOARD_CACHE_TTL,
        );

        this.logger.info("Leaderboard snapshots precomputed (all-time, month, week)");
    }

    // ─── Private ────────────────────────────────────────────

    private async computeAndCacheLeaderboard(
        cacheKey: string,
        since?: string,
        until?: string,
        limit = 10,
    ): Promise<LeaderboardResult> {
        // Try to acquire lock
        const lockKey = `lock:leaderboard:${cacheKey}`;
        const locked = await this.tryAcquireLock(lockKey);

        if (!locked) {
            // Another request is already computing — wait briefly and try cache again
            await new Promise((r) => setTimeout(r, 500));
            const retryCache = await this.scoresKv.get<LeaderboardResult>(cacheKey);
            if (retryCache?.data) return retryCache.data;
            // Still no cache — compute anyway (lock expired or was released)
        }

        try {
            const entries = await this.d1.getLeaderboard(since, until, limit);
            const result: LeaderboardResult = {
                entries,
                cachedAt: new Date().toISOString(),
                since: since || null,
                until: until || null,
            };

            await this.scoresKv.set(cacheKey, result, LEADERBOARD_CACHE_TTL);
            this.logger.info({ since, until, count: entries.length }, "Leaderboard computed and cached");
            return result;
        } finally {
            await this.releaseLock(lockKey);
        }
    }

    private async tryAcquireLock(lockKey: string): Promise<boolean> {
        try {
            const existing = await this.scoresKv.get<boolean>(lockKey);
            if (existing?.data) return false; // Already locked
            await this.scoresKv.set(lockKey, true, LOCK_TTL);
            return true;
        } catch {
            return true; // If lock check fails, proceed anyway
        }
    }

    private async releaseLock(lockKey: string): Promise<void> {
        try {
            await this.scoresKv.del(lockKey);
        } catch {
            // Lock will expire via TTL anyway
        }
    }

    private leaderboardCacheKey(since?: string, until?: string): string {
        return `leaderboard:${since || "all"}:${until || "all"}`;
    }
}
