/**
 * Scores Module — Score Aggregation Service (Relational)
 *
 * Computes leaderboards from the normalized relational tables
 * (merged_prs, pr_comment_summary, meeting_attendance) using
 * D1RelationalService.
 *
 * Supports incremental updates — only refreshes the affected developer's
 * entry in the cached snapshot when called from a webhook.
 *
 * Periods:
 *   leaderboard:all   — all time
 *   leaderboard:month — current calendar month (UTC)
 *   leaderboard:week  — current Mon–Sun week (UTC)
 */

import type { ScoresRepository, RelationalLeaderboardEntry } from "./scores.repository";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";

/** Cache TTL for leaderboard snapshots (6 hours — also refreshed by cron) */
const LEADERBOARD_CACHE_TTL = 6 * 60 * 60;
const LOCK_TTL = 30;

export type LeaderboardPeriod = "all" | "month" | "week";

export interface LeaderboardResult {
    entries: RelationalLeaderboardEntry[];
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
    const day = now.getUTCDay();
    const mondayOffset = day === 0 ? 6 : day - 1;
    const since = new Date(
        Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - mondayOffset),
    ).toISOString();
    return { since, until: null };
}

function periodCacheKey(period: LeaderboardPeriod): string {
    return `leaderboard:${period}`;
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
     * Get leaderboard for a named period.
     * Served from KV cache if available, otherwise computed and cached.
     */
    async getLeaderboard(period: LeaderboardPeriod = "all", limit = 50): Promise<LeaderboardResult> {
        const cacheKey = periodCacheKey(period);
        const cached = await this.scoresKv.get<LeaderboardResult>(cacheKey);
        if (cached?.data) {
            this.logger.info({ period }, "Leaderboard served from KV cache");
            return cached.data;
        }
        return this.computeAndCachePeriod(period, limit);
    }

    /**
     * Precompute ALL three leaderboard snapshots.
     * Called by: Cron (every 6h), POST /api/sync/github, full refresh.
     *
     * @param developerLogins — optional array of logins to update INCREMENTALLY.
     *   If provided, only those developers' entries are refreshed in the cached snapshot.
     *   This avoids a full D1 UNION ALL query for every single webhook call.
     */
    async precomputeSnapshots(developerLogins?: string[]): Promise<void> {
        if (developerLogins && developerLogins.length > 0) {
            // ── Incremental update — only patch affected developers ──────────
            this.logger.info({ developers: developerLogins }, "Incremental leaderboard update");
            await Promise.all([
                this.patchDevelopersInSnapshot("all", developerLogins),
                this.patchDevelopersInSnapshot("month", developerLogins),
                this.patchDevelopersInSnapshot("week", developerLogins),
            ]);
        } else {
            // ── Full recompute — called by cron or full sync ─────────────────
            this.logger.info("Full leaderboard snapshot recompute (all, month, week)");
            await Promise.all([
                this.computeAndCachePeriod("all", 50),
                this.computeAndCachePeriod("month", 50),
                this.computeAndCachePeriod("week", 50),
            ]);
            this.logger.info("All leaderboard snapshots updated");
        }
    }

    /**
     * Patch one or more developers inside an existing cached snapshot.
     * Fetches fresh data per developer and splices it in — O(n) per developer.
     */
    private async patchDevelopersInSnapshot(
        period: LeaderboardPeriod,
        developerLogins: string[],
    ): Promise<void> {
        const cacheKey = periodCacheKey(period);
        const cached = await this.scoresKv.get<LeaderboardResult>(cacheKey);

        if (!cached?.data) {
            // No snapshot yet — do a full recompute instead
            await this.computeAndCachePeriod(period, 50);
            return;
        }

        const { since, until } = periodBounds(period);
        const snapshot = cached.data;

        for (const login of developerLogins) {
            const freshEntry = await this.scoresRepo.getDeveloperLeaderboardEntry(login, since ?? undefined, until ?? undefined);

            // Remove old entry (if any)
            snapshot.entries = snapshot.entries.filter((e) => e.developer_login !== login);

            // Add fresh entry (if they have any activity)
            if (freshEntry && freshEntry.total_points > 0) {
                snapshot.entries.push(freshEntry);
            }
        }

        // Re-sort descending by points
        snapshot.entries.sort((a, b) => b.total_points - a.total_points);
        snapshot.cachedAt = new Date().toISOString();

        await this.scoresKv.set(cacheKey, snapshot, LEADERBOARD_CACHE_TTL);
        this.logger.info({ period, developers: developerLogins }, "Incremental snapshot patch saved");
    }

    // ─── Private ─────────────────────────────────────────────

    private async computeAndCachePeriod(
        period: LeaderboardPeriod,
        limit: number,
    ): Promise<LeaderboardResult> {
        const cacheKey = periodCacheKey(period);
        const lockKey = `lock:${cacheKey}`;

        const locked = await this.tryAcquireLock(lockKey);
        if (!locked) {
            await new Promise((r) => setTimeout(r, 600));
            const retryCache = await this.scoresKv.get<LeaderboardResult>(cacheKey);
            if (retryCache?.data) return retryCache.data;
        }

        try {
            const { since, until } = periodBounds(period);
            const entries = await this.scoresRepo.getLeaderboard(since ?? undefined, until ?? undefined, limit);

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
        } catch { /* expires via TTL */ }
    }
}
