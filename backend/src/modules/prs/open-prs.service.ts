/**
 * PRs — Open PRs Service
 *
 * Single Responsibility: Fetch all open PRs across the entire organization
 * using the GitHub Search API, and enrich them with reviews and comments.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { RateLimitGuard } from "../../infra/github/rate-limit-guard";
import type { Logger } from "../../core/logger";
import type { Env } from "../../config/env";
import type { LogsService } from "../logs/logs.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { PrMetric } from "../../core/types";
import { GitHubApiError } from "../../core/errors";
import { mapToPrMetric } from "../metrics/metrics.mapper";

/** Batch size for parallel PR enrichment (avoids GitHub rate limits). */
const BATCH_SIZE = 10;

export class OpenPrsService {
    private readonly github: CachedGitHubClient;
    private readonly guard: RateLimitGuard;
    private readonly logger: Logger;
    private readonly logsService: LogsService;
    private readonly cacheService: CacheService;
    private readonly requiredApprovals: number;

    constructor({
        cachedGithubClient,
        rateLimitGuard,
        logger,
        logsService,
        cacheService,
        env,
    }: {
        cachedGithubClient: CachedGitHubClient;
        rateLimitGuard: RateLimitGuard;
        logger: Logger;
        logsService: LogsService;
        cacheService: CacheService;
        env: Env;
    }) {
        this.github = cachedGithubClient;
        this.guard = rateLimitGuard;
        this.logger = logger.child({ module: "open-prs" });
        this.logsService = logsService;
        this.cacheService = cacheService;
        this.requiredApprovals = env.requiredApprovals;
    }

    /**
     * Search all open PRs in the organization and return fully-enriched metrics.
     */
    async fetchOpenPrs(org: string, perPage = 100): Promise<PrMetric[]> {
        const cacheKey = `github:open_prs:${org}`;
        
        try {
            const cached = await this.cacheService.get<PrMetric[]>(cacheKey);
            if (cached) {
                this.logger.info({ org }, "Returning open PRs from cache");
                return cached.data;
            }

            this.logger.info({ org }, "Searching open PRs from GitHub");

            const searchResults = await this.github.searchOpenPrsForOrg(org, perPage);
            this.logger.info({ count: searchResults.length }, "Open PRs found, enriching…");

            this.logsService.log(
                `Found ${searchResults.length} open PRs across ${org}`,
                "info",
                "github",
                { org, count: searchResults.length }
            );

            const enriched = await this.enrichInBatches(searchResults);
            
            // Cache for a long duration, let webhooks invalidate it
            await this.cacheService.set(cacheKey, enriched, 24 * 60 * 60); // 24 hours
            return enriched;
        } catch (err: any) {
            if (err instanceof GitHubApiError) throw err;
            throw new GitHubApiError(`Failed to fetch open PRs for ${org}: ${err.message}`);
        }
    }

    /**
     * Invalidate the open PRs cache for the organization.
     */
    async invalidateCache(org: string): Promise<void> {
        await this.cacheService.del(`github:open_prs:${org}`);
        this.logger.info({ org }, "Invalidated open PRs cache");
    }

    // ─── Private ─────────────────────────────────────────────

    private async enrichInBatches(items: any[]): Promise<PrMetric[]> {
        const results: PrMetric[] = [];
        for (let i = 0; i < items.length; i += BATCH_SIZE) {
            await this.guard.checkAndWait();
            const batch = items.slice(i, i + BATCH_SIZE);
            const enriched = await Promise.all(batch.map((item) => this.enrichSingle(item)));
            results.push(...enriched);
        }
        return results;
    }

    private async enrichSingle(searchItem: any): Promise<PrMetric> {
        // The search API returns issue items. We need to extract repo details.
        // repository_url is like "https://api.github.com/repos/Sellio-Squad/sellio_mobile"
        const repoUrlParts = searchItem.repository_url.split("/");
        const repoName = repoUrlParts.pop();
        const ownerName = repoUrlParts.pop();

        if (!ownerName || !repoName) {
            this.logger.error({ url: searchItem.repository_url }, "Could not parse repository URL");
            throw new Error(`Invalid repository URL: ${searchItem.repository_url}`);
        }

        const pullNumber = searchItem.number;
        
        // Since we explicitly searched for is:open, we know these are open
        const isOpen = true;

        const [fullPr, reviews, issueComments, reviewComments] = await Promise.all([
            this.github.getPull(ownerName, repoName, pullNumber, isOpen).catch(() => searchItem),
            this.github.listReviews(ownerName, repoName, pullNumber, isOpen).catch(() => []),
            this.github.listIssueComments(ownerName, repoName, pullNumber, isOpen).catch(() => []),
            this.github.listReviewComments(ownerName, repoName, pullNumber, isOpen).catch(() => []),
        ]);

        return mapToPrMetric({
            pr: fullPr,
            reviews: reviews as any,
            issueComments: issueComments as any,
            reviewComments: reviewComments as any,
            requiredApprovals: this.requiredApprovals,
        });
    }
}
