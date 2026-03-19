/**
 * Scores Module — Score Aggregation Service
 *
 * On-demand leaderboard aggregation from D1 (events JOIN point_rules).
 * Results cached in SCORES_KV for fast reads.
 *
 * Periods precomputed by Cron (every 6h) and after every sync/webhook:
 *   - leaderboard:all          — all time
 *   - leaderboard:month        — current calendar month (UTC)
 *   - leaderboard:week         — current Mon–Sun week (UTC)
 */

import type { D1Service } from "../../infra/database/d1.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { AggregatedLeaderboardEntry } from "../../core/event-types";

/** Cache TTL for leaderboard snapshots (6 hours — refreshed by cron) */
const LEADERBOARD_CACHE_TTL = 6 * 60 * 60;
/** Lock TTL — 30 seconds max */
const LOCK_TTL = 30;

export type LeaderboardPeriod = "all" | "month" | "week";

export interface LeaderboardResult {
    entries: AggregatedLeaderboardEntry[];
    cachedAt: string;
    period: LeaderboardPeriod;
    since: string | null;
    until: string | null;
}

// ─── Period helpers ──────────────────────────────────────

function periodBounds(period: LeaderboardPeriod): { since: string | null; until: null } {
    const now = new Date();
    if (period === "all") return { since: null, until: null };

    if (period === "month") {
        const since = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
        return { since, until: null };
    }

    // week — Monday-based ISO week
    const day = now.getUTCDay(); // 0=Sun
    const mondayOffset = day === 0 ? 6 : day - 1;
    const since = new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - mondayOffset),
    ).toISOString();
    return { since, until: null };
}

/** Stable KV key for a named period — never changes mid-period */
function periodCacheKey(period: LeaderboardPeriod): string {
    return `leaderboard:${period}`;
}

// ─── Service ─────────────────────────────────────────────

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
     * Get leaderboard for a named period (all | month | week).
     * Served directly from KV cache if available; otherwise computed from D1 and cached.
     */
    async getLeaderboard(period: LeaderboardPeriod = "all", limit = 50): Promise<LeaderboardResult> {
        const cacheKey = periodCacheKey(period);

        const cached = await this.scoresKv.get<LeaderboardResult>(cacheKey);
        if (cached?.data) {
            this.logger.info({ period }, "Leaderboard served from KV cache");
            return cached.data;
        }

        // Cache miss — compute and cache
        return this.computeAndCachePeriod(period, limit);
    }

    /**
     * Precompute ALL three leaderboard snapshots and write them to KV.
     * Called by: Cron Trigger (every 6h), POST /api/sync/github, webhook handler.
     *
     * Each period gets a STABLE key (leaderboard:all, leaderboard:month, leaderboard:week)
     * so clients never need to derive date bounds — they just request by period name.
     */
    async precomputeSnapshots(): Promise<void> {
        this.logger.info("Precomputing leaderboard snapshots (all, month, week)");

        await Promise.all([
            this.computeAndCachePeriod("all", 50),
            this.computeAndCachePeriod("month", 50),
            this.computeAndCachePeriod("week", 50),
        ]);

        this.logger.info("All leaderboard snapshots updated");
    }

    /**
     * Get score for a single developer (reads from any existing snapshot).
     */
    async getDeveloperScore(
        developerId: string,
        period: LeaderboardPeriod = "all",
    ): Promise<{ developerId: string; totalPoints: number; eventCounts: Record<string, number> } | null> {
        const snapshot = await this.getLeaderboard(period);
        const entry = snapshot.entries.find((e) => e.developer_id === developerId);
        if (!entry) return null;
        return {
            developerId: entry.developer_id,
            totalPoints: entry.total_points,
            eventCounts: entry.event_counts,
        };
    }

    // ─── Private ────────────────────────────────────────────

    private async computeAndCachePeriod(
        period: LeaderboardPeriod,
        limit: number,
    ): Promise<LeaderboardResult> {
        const cacheKey = periodCacheKey(period);
        const lockKey = `lock:${cacheKey}`;

        const locked = await this.tryAcquireLock(lockKey);
        if (!locked) {
            // Another request is already computing — wait briefly and try cache again
            await new Promise((r) => setTimeout(r, 600));
            const retryCache = await this.scoresKv.get<LeaderboardResult>(cacheKey);
            if (retryCache?.data) return retryCache.data;
        }

        try {
            const { since, until } = periodBounds(period);
            const entries = await this.d1.getLeaderboard(
                since ?? undefined,
                until ?? undefined,
                limit,
            );

            const result: LeaderboardResult = {
                entries,
                cachedAt: new Date().toISOString(),
                period,
                since,
                until,
            };

            await this.scoresKv.set(cacheKey, result, LEADERBOARD_CACHE_TTL);
            this.logger.info({ period, since, count: entries.length }, "Leaderboard snapshot cached");
            return result;
        } finally {
            await this.releaseLock(lockKey);
        }
    }

    private async tryAcquireLock(lockKey: string): Promise<boolean> {
        try {
            const existing = await this.scoresKv.get<boolean>(lockKey);
            if (existing?.data) return false;
            await this.scoresKv.set(lockKey, true, LOCK_TTL);
            return true;
        } catch {
            return true;
        }
    }

    private async releaseLock(lockKey: string): Promise<void> {
        try {
            await this.scoresKv.del(lockKey);
        } catch {
            // Expires via TTL
        }
    }
}
