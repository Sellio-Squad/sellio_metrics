/**
 * Metrics — PR Fetcher Service
 *
 * Single Responsibility: Fetch all PRs for a repo from GitHub and
 * enrich each one with reviews and comments.
 *
 * Does NOT know about caching — that is the ResultCacheService's job.
 * Does NOT know about leaderboard or member status — those are calculators.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { RateLimitGuard } from "../../infra/github/rate-limit-guard";
import type { Logger } from "../../core/logger";
import type { Env } from "../../config/env";
import type { LogsService } from "../logs/logs.service";
import type { PrMetric } from "../../core/types";
import { GitHubApiError } from "../../core/errors";
import { mapToPrMetric } from "./metrics.mapper";

/** Batch size for parallel PR enrichment (avoids GitHub rate limits). */
// BATCH_SIZE is no longer used, switching to sequential to avoid secondary limits


export class PrFetcherService {
    private readonly github: CachedGitHubClient;
    private readonly guard: RateLimitGuard;
    private readonly logger: Logger;
    private readonly logsService: LogsService;
    private readonly requiredApprovals: number;

    constructor({
        cachedGithubClient,
        rateLimitGuard,
        logger,
        logsService,
        env,
    }: {
        cachedGithubClient: CachedGitHubClient;
        rateLimitGuard: RateLimitGuard;
        logger: Logger;
        logsService: LogsService;
        env: Env;
    }) {
        this.github = cachedGithubClient;
        this.guard = rateLimitGuard;
        this.logger = logger.child({ module: "pr-fetcher" });
        this.logsService = logsService;
        this.requiredApprovals = env.requiredApprovals;
    }

    /**
     * Fetch all PRs for a repo and return fully-enriched metrics.
     * Makes multiple GitHub API calls — callers should check result cache
     * before calling this.
     */
    async fetch(
        owner: string,
        repo: string,
        state: "all" | "open" | "closed" = "all",
        perPage = 100,
    ): Promise<PrMetric[]> {
        this.logger.info({ owner, repo, state }, "Fetching PRs from GitHub");

        try {
            const pulls = await this.github.listPulls(owner, repo, state, perPage);
            this.logger.info({ count: pulls.length }, "PRs fetched, enriching…");
            
            this.logsService.log(
                `Fetched ${pulls.length} PRs from GitHub (${state})`,
                "info",
                "github",
                { owner, repo, state, count: pulls.length }
            );

            return await this.enrichInBatches(owner, repo, pulls);
        } catch (err: any) {
            if (err instanceof GitHubApiError) throw err;
            throw new GitHubApiError(`Failed to fetch PRs for ${owner}/${repo}: ${err.message}`);
        }
    }

    // ─── Private ─────────────────────────────────────────────

    private async enrichInBatches(owner: string, repo: string, pulls: any[]): Promise<PrMetric[]> {
        const results: PrMetric[] = [];
        for (const pr of pulls) {
            await this.guard.checkAndWait();
            const enriched = await this.enrichSingle(owner, repo, pr);
            results.push(enriched);
            // Small delay to prevent secondary rate limits from GitHub API
            await new Promise((resolve) => setTimeout(resolve, 100));
        }
        return results;
    }

    private async enrichSingle(owner: string, repo: string, pr: any): Promise<PrMetric> {
        const isOpen = !pr.merged_at && !pr.closed_at;
        const [fullPr, reviews, issueComments, reviewComments] = await Promise.all([
            this.github.getPull(owner, repo, pr.number, isOpen).catch((e: any) => { this.logger.error({ err: e.message, pr: pr.number }, "getPull failed"); return pr; }),
            this.github.listReviews(owner, repo, pr.number, isOpen).catch((e: any) => { this.logger.error({ err: e.message, pr: pr.number }, "listReviews failed"); return []; }),
            this.github.listIssueComments(owner, repo, pr.number, isOpen).catch((e: any) => { this.logger.error({ err: e.message, pr: pr.number }, "listIssueComments failed"); return []; }),
            this.github.listReviewComments(owner, repo, pr.number, isOpen).catch((e: any) => { this.logger.error({ err: e.message, pr: pr.number }, "listReviewComments failed"); return []; }),
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
