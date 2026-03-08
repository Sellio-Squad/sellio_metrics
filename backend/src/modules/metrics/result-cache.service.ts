/**
 * Metrics — Result Cache Service
 *
 * Single Responsibility: Typed KV get/set for pre-computed metric results.
 *
 * Knows about CacheService and result key naming conventions.
 * Does NOT know about GitHub, calculators, or business logic.
 *
 * KV Write Budget: 1 write per result type per repo (≤3 total per request).
 */

import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { PrMetric, LeaderboardEntry } from "../../core/types";
import type { MemberStatus } from "./members.calculator";

/** All cached results expire after 1 hour. */
const RESULT_TTL = 60 * 60;

export interface CachedResult<T> {
    owner: string;
    repo: string;
    cachedAt: string;
    data: T;
}

export class ResultCacheService {
    private readonly cache: CacheService;
    private readonly logger: Logger;

    constructor({ cacheService, logger }: { cacheService: CacheService; logger: Logger }) {
        this.cache = cacheService;
        this.logger = logger.child({ module: "result-cache" });
    }

    // ─── PR Metrics ──────────────────────────────────────────

    async getPrMetrics(owner: string, repo: string, state: string): Promise<PrMetric[] | null> {
        const hit = await this.cache.get<PrMetric[]>(this.metricsKey(owner, repo, state));
        if (hit) this.logger.info({ owner, repo }, "✅ PR metrics from cache");
        return hit?.data ?? null;
    }

    async setPrMetrics(owner: string, repo: string, state: string, data: PrMetric[]): Promise<void> {
        await this.cache.set(this.metricsKey(owner, repo, state), data, RESULT_TTL);
        this.logger.info({ owner, repo, count: data.length }, "PR metrics cached (1 KV write)");
    }

    async invalidatePrMetrics(owner: string, repo: string): Promise<void> {
        await Promise.all([
            this.cache.del(this.metricsKey(owner, repo, "all")),
            this.cache.del(this.metricsKey(owner, repo, "open")),
            this.cache.del(this.metricsKey(owner, repo, "closed")),
        ]);
    }

    // ─── Leaderboard ─────────────────────────────────────────

    async getLeaderboard(owner: string, repo: string): Promise<CachedResult<LeaderboardEntry[]> | null> {
        const hit = await this.cache.get<LeaderboardEntry[]>(this.leaderboardKey(owner, repo));
        if (!hit) return null;
        return { owner, repo, cachedAt: hit.cachedAt, data: hit.data };
    }

    async setLeaderboard(owner: string, repo: string, entries: LeaderboardEntry[]): Promise<void> {
        await this.cache.set(this.leaderboardKey(owner, repo), entries, RESULT_TTL);
        this.logger.info({ owner, repo, count: entries.length }, "Leaderboard cached (1 KV write)");
    }

    // ─── Members ─────────────────────────────────────────────

    async getMembers(owner: string, repo: string): Promise<CachedResult<MemberStatus[]> | null> {
        const hit = await this.cache.get<MemberStatus[]>(this.membersKey(owner, repo));
        if (!hit) return null;
        return { owner, repo, cachedAt: hit.cachedAt, data: hit.data };
    }

    async setMembers(owner: string, repo: string, members: MemberStatus[]): Promise<void> {
        await this.cache.set(this.membersKey(owner, repo), members, RESULT_TTL);
        this.logger.info({ owner, repo, count: members.length }, "Members cached (1 KV write)");
    }

    // ─── Cache Status (for debug endpoint) ───────────────────

    async getStatus(owner: string, repo: string): Promise<{
        metrics: boolean; metricsAge: string | null;
        leaderboard: boolean; leaderboardAge: string | null;
        members: boolean; membersAge: string | null;
    }> {
        const [m, l, mb] = await Promise.all([
            this.cache.get<any>(this.metricsKey(owner, repo, "all")),
            this.cache.get<any>(this.leaderboardKey(owner, repo)),
            this.cache.get<any>(this.membersKey(owner, repo)),
        ]);
        return {
            metrics: !!m, metricsAge: m?.cachedAt ?? null,
            leaderboard: !!l, leaderboardAge: l?.cachedAt ?? null,
            members: !!mb, membersAge: mb?.cachedAt ?? null,
        };
    }

    // ─── Keys ──────────────────────────────────────────────

    private metricsKey(owner: string, repo: string, state: string) {
        return `result:metrics:${owner}/${repo}:${state}`;
    }
    private leaderboardKey(owner: string, repo: string) {
        return `result:leaderboard:${owner}/${repo}`;
    }
    private membersKey(owner: string, repo: string) {
        return `result:members:${owner}/${repo}`;
    }
}
