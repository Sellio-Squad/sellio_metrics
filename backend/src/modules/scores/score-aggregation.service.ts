/**
 * Scores Module — Score Aggregation Service (Relational)
 *
 * Computes leaderboards from the normalized relational tables.
 *
 * Filter options (all optional):
 *   since     — ISO-8601 start date
 *   until     — ISO-8601 end date
 *   repoNames — filter to specific repo names
 *
 * When NO filters are provided the all-time KV cache is served.
 * When ANY filter is provided the cache is bypassed.
 */

import type { ScoresRepository, RelationalLeaderboardEntry } from "./scores.repository";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";

/** Cache TTL for leaderboard snapshots (6 hours — also refreshed by cron) */
const LEADERBOARD_CACHE_TTL = 6 * 60 * 60;
const LOCK_TTL = 30;
const ALL_TIME_CACHE_KEY = "leaderboard:all";

export interface LeaderboardResult {
    entries: RelationalLeaderboardEntry[];
    cachedAt: string;
    since: string | null;
    until: string | null;
    repoIds: number[];
}

// ─── Service ─────────────────────────────────────────────

export class ScoreAggregationService {
    private readonly scoresRepo: ScoresRepository;
    private readonly scoresKv: CacheService;
    private readonly logger: Logger;

    constructor({
        scoresRepo,
        scoresKvCache,
        logger,
    }: {
        scoresRepo: ScoresRepository;
        scoresKvCache: CacheService;
        logger: Logger;
    }) {
        this.scoresRepo = scoresRepo;
        this.scoresKv = scoresKvCache;
        this.logger = logger.child({ module: "score-aggregation" });
    }

    /**
     * Get leaderboard, optionally filtered by date range and/or repo names.
     *
     * - No filters → served from KV cache (all-time snapshot).
     * - Any filter  → computed live, cache is bypassed.
     */
    async getLeaderboard(
        limit = 50,
        since?: string,
        until?: string,
        repoIds: number[] = [],
    ): Promise<LeaderboardResult> {
        // Defensive: ensure repoIds is always an array (protects against corrupt KV cache deserialization)
        const safeRepoIds = Array.isArray(repoIds) ? repoIds : [];
        const hasFilters = !!since || !!until || safeRepoIds.length > 0;

        if (!hasFilters) {
            const cached = await this.scoresKv.get<LeaderboardResult>(ALL_TIME_CACHE_KEY);
            if (cached?.data) {
                // Also guard cached data in case it was stored with a corrupt shape
                const data = cached.data;
                data.entries  = Array.isArray(data.entries)  ? data.entries  : [];
                data.repoIds  = Array.isArray(data.repoIds)  ? data.repoIds  : [];
                this.logger.info("Leaderboard served from KV cache");
                return data;
            }
        }

        return this.computeAndCache(limit, since, until, safeRepoIds, !hasFilters);
    }

    /**
     * Precompute the all-time leaderboard snapshot.
     * Called by: Cron (every 6h), POST /api/sync/github, full refresh.
     *
     * @param developerLogins — optional array of logins for incremental update.
     */
    async precomputeSnapshots(developerLogins?: string[]): Promise<void> {
        if (developerLogins && developerLogins.length > 0) {
            this.logger.info({ developers: developerLogins }, "Incremental all-time leaderboard update");
            await this.patchDevelopersInSnapshot(developerLogins);
        } else {
            this.logger.info("Full leaderboard snapshot recompute (all-time)");
            await this.computeAndCache(50, undefined, undefined, [], true);
            this.logger.info("All-time leaderboard snapshot updated");
        }
    }

    /** Delete the all-time leaderboard KV snapshot and its lock key. */
    async bustCache(): Promise<void> {
        try { await this.scoresKv.del(ALL_TIME_CACHE_KEY); } catch { /* ok */ }
        try { await this.scoresKv.del(`lock:${ALL_TIME_CACHE_KEY}`); } catch { /* ok */ }
        this.logger.info("Leaderboard KV cache busted");
    }

    /**
     * Patch one or more developers inside the all-time cached snapshot.
     */
    private async patchDevelopersInSnapshot(developerLogins: string[]): Promise<void> {
        const cached = await this.scoresKv.get<LeaderboardResult>(ALL_TIME_CACHE_KEY);

        if (!cached?.data) {
            await this.computeAndCache(50, undefined, undefined, [], true);
            return;
        }

        const snapshot = cached.data;

        for (const login of developerLogins) {
            const freshEntry = await this.scoresRepo.getDeveloperLeaderboardEntry(login);

            snapshot.entries = snapshot.entries.filter((e) => e.developer_login !== login);
            if (freshEntry && freshEntry.total_points > 0) {
                snapshot.entries.push(freshEntry);
            }
        }

        snapshot.entries.sort((a, b) => b.total_points - a.total_points);
        snapshot.cachedAt = new Date().toISOString();

        await this.scoresKv.set(ALL_TIME_CACHE_KEY, snapshot, LEADERBOARD_CACHE_TTL);
        this.logger.info({ developers: developerLogins }, "Incremental snapshot patch saved");
    }

    // ─── Private ─────────────────────────────────────────────

    private async computeAndCache(
        limit: number,
        since: string | undefined,
        until: string | undefined,
        repoIds: number[],
        shouldCache: boolean,
    ): Promise<LeaderboardResult> {
        const lockKey = `lock:${ALL_TIME_CACHE_KEY}`;
        const locked = shouldCache ? await this.tryAcquireLock(lockKey) : true;

        if (shouldCache && !locked) {
            await new Promise((r) => setTimeout(r, 600));
            const retryCache = await this.scoresKv.get<LeaderboardResult>(ALL_TIME_CACHE_KEY);
            if (retryCache?.data) return retryCache.data;
        }

        try {
            const entries = await this.scoresRepo.getLeaderboard(since, until, limit, repoIds);
            const result: LeaderboardResult = {
                entries,
                cachedAt: new Date().toISOString(),
                since: since ?? null,
                until: until ?? null,
                repoIds,
            };

            if (shouldCache) {
                await this.scoresKv.set(ALL_TIME_CACHE_KEY, result, LEADERBOARD_CACHE_TTL);
                this.logger.info({ count: entries.length }, "Leaderboard snapshot cached");
            }

            return result;
        } finally {
            if (shouldCache) await this.releaseLock(lockKey);
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
        } catch { /* expires via TTL */ }
    }
}
