/**
 * Metrics Module — Service
 *
 * Orchestrates GitHub API calls through the CachedGitHubClient
 * and delegates mapping.
 *
 * Result-Level Caching:
 *   The final computed PrMetric[] array is cached in Redis per repo.
 *   This turns a 30-second, 600+ API call operation into a single
 *   Redis GET (sub-millisecond) on subsequent requests.
 *   Cache is invalidated by the webhook route when GitHub notifies
 *   us of PR events.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { CacheService } from "../../infra/cache/cache.service";
import type { RateLimitGuard } from "../../infra/github/rate-limit-guard";
import type { Logger } from "../../core/logger";
import type { Env } from "../../config/env";
import type { PrMetric } from "../../core/types";
import { GitHubApiError } from "../../core/errors";
import { mapToPrMetric } from "./metrics.mapper";

/** TTL for the cached result (1 hour). */
const RESULT_CACHE_TTL = 60 * 60;

export class MetricsService {
    private readonly cachedGithubClient: CachedGitHubClient;
    private readonly cacheService: CacheService;
    private readonly rateLimitGuard: RateLimitGuard;
    private readonly logger: Logger;
    private readonly env: Env;

    /** Batch size for parallel PR enrichment (avoids GitHub rate limits). */
    private static readonly BATCH_SIZE = 10;

    constructor({
        cachedGithubClient,
        cacheService,
        rateLimitGuard,
        logger,
        env,
    }: {
        cachedGithubClient: CachedGitHubClient;
        cacheService: CacheService;
        rateLimitGuard: RateLimitGuard;
        logger: Logger;
        env: Env;
    }) {
        this.cachedGithubClient = cachedGithubClient;
        this.cacheService = cacheService;
        this.rateLimitGuard = rateLimitGuard;
        this.logger = logger.child({ module: "metrics" });
        this.env = env;
    }

    /**
     * Fetches PR metrics with result-level caching.
     * On cache HIT: returns instantly from Redis.
     * On cache MISS: fetches from GitHub, computes, caches, then returns.
     */
    async fetchPrMetrics(
        owner: string,
        repo: string,
        options: { state?: "all" | "open" | "closed"; perPage?: number } = {},
    ): Promise<PrMetric[]> {
        const { state = "all", perPage = 100 } = options;
        const cacheKey = `result:metrics:${owner}/${repo}:${state}`;

        // Check result cache first
        const cached = await this.cacheService.get<PrMetric[]>(cacheKey);
        if (cached) {
            this.logger.info(
                { owner, repo, state, count: cached.data.length },
                "Serving metrics from result cache (instant)",
            );
            return cached.data;
        }

        this.logger.info({ owner, repo, state }, "Result cache MISS — fetching from GitHub");

        try {
            // Step 1: Paginate all PRs (resource-level cache may help here)
            const pulls = await this.cachedGithubClient.listPulls(owner, repo, state, perPage);
            this.logger.info({ count: pulls.length }, "PRs fetched, enriching…");

            // Step 2: Enrich each PR in batches (parallel within batch)
            const results = await this.enrichInBatches(owner, repo, pulls);

            // Step 3: Cache the final computed result
            await this.cacheService.set(cacheKey, results, RESULT_CACHE_TTL);
            this.logger.info(
                { count: results.length, ttl: RESULT_CACHE_TTL },
                "Metrics computed and cached",
            );

            return results;
        } catch (error: any) {
            if (error instanceof GitHubApiError) throw error;
            this.logger.error({ error: error.message }, "Failed to fetch metrics");
            throw new GitHubApiError(`Failed to fetch metrics: ${error.message}`);
        }
    }

    // ─── Private: Enrich ─────────────────────────────────────

    private async enrichInBatches(
        owner: string,
        repo: string,
        pulls: any[],
    ): Promise<PrMetric[]> {
        const results: PrMetric[] = [];

        for (let i = 0; i < pulls.length; i += MetricsService.BATCH_SIZE) {
            // Rate limit guard: check before each batch
            await this.rateLimitGuard.checkAndWait();

            const batch = pulls.slice(i, i + MetricsService.BATCH_SIZE);
            const enriched = await Promise.all(
                batch.map((pr) => this.enrichSinglePr(owner, repo, pr)),
            );
            results.push(...enriched);

            if (i + MetricsService.BATCH_SIZE < pulls.length) {
                this.logger.debug(
                    { progress: `${Math.min(i + MetricsService.BATCH_SIZE, pulls.length)}/${pulls.length}` },
                    "Enrichment progress",
                );
            }
        }

        return results;
    }

    private async enrichSinglePr(
        owner: string,
        repo: string,
        pr: any,
    ): Promise<PrMetric> {
        const prNumber = pr.number;
        const isOpen = !pr.merged_at && !pr.closed_at;

        const [fullPr, reviews, issueComments, reviewComments] = await Promise.all([
            this.cachedGithubClient
                .getPull(owner, repo, prNumber, isOpen)
                .catch(() => pr),
            this.cachedGithubClient
                .listReviews(owner, repo, prNumber, isOpen)
                .catch(() => []),
            this.cachedGithubClient
                .listIssueComments(owner, repo, prNumber, isOpen)
                .catch(() => []),
            this.cachedGithubClient
                .listReviewComments(owner, repo, prNumber, isOpen)
                .catch(() => []),
        ]);

        // Delegate all transformation to the mapper
        return mapToPrMetric({
            pr: fullPr,
            reviews: reviews as any,
            issueComments: issueComments as any,
            reviewComments: reviewComments as any,
            requiredApprovals: this.env.requiredApprovals,
        });
    }
}
