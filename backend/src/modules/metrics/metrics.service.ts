/**
 * Metrics Module — Service
 *
 * Orchestrates GitHub API calls and delegates mapping.
 * No HTTP concerns — that's the route's job.
 * No raw data transformation — that's the mapper's job.
 */

import type { GitHubClient } from "../../infra/github/github.client";
import type { Logger } from "../../core/logger";
import type { Env } from "../../config/env";
import type { PrMetric } from "../../core/types";
import { GitHubApiError } from "../../core/errors";
import { mapToPrMetric } from "./metrics.mapper";

export class MetricsService {
    private readonly githubClient: GitHubClient;
    private readonly logger: Logger;
    private readonly env: Env;

    /** Batch size for parallel PR enrichment (avoids GitHub rate limits). */
    private static readonly BATCH_SIZE = 10;

    constructor({
        githubClient,
        logger,
        env,
    }: {
        githubClient: GitHubClient;
        logger: Logger;
        env: Env;
    }) {
        this.githubClient = githubClient;
        this.logger = logger.child({ module: "metrics" });
        this.env = env;
    }

    /**
     * Fetches all PRs for a repository, enriches them with reviews/comments,
     * and returns domain PrMetric objects.
     */
    async fetchPrMetrics(
        owner: string,
        repo: string,
        options: { state?: "all" | "open" | "closed"; perPage?: number } = {},
    ): Promise<PrMetric[]> {
        const { state = "all", perPage = 100 } = options;

        this.logger.info({ owner, repo, state }, "Fetching PR metrics");

        try {
            // Step 1: Paginate all PRs
            const pulls = await this.fetchAllPulls(owner, repo, state, perPage);
            this.logger.info({ count: pulls.length }, "PRs fetched, enriching…");

            // Step 2: Enrich each PR in batches (parallel within batch)
            const results = await this.enrichInBatches(owner, repo, pulls);

            this.logger.info({ count: results.length }, "Metrics ready");
            return results;
        } catch (error: any) {
            if (error instanceof GitHubApiError) throw error;
            this.logger.error({ error: error.message }, "Failed to fetch metrics");
            throw new GitHubApiError(`Failed to fetch metrics: ${error.message}`);
        }
    }

    // ─── Private: Fetch ──────────────────────────────────────

    private async fetchAllPulls(
        owner: string,
        repo: string,
        state: "all" | "open" | "closed",
        perPage: number,
    ) {
        return this.githubClient.paginate(
            this.githubClient.rest.pulls.list,
            { owner, repo, state, sort: "created", direction: "desc", per_page: perPage },
        );
    }

    // ─── Private: Enrich ─────────────────────────────────────

    private async enrichInBatches(
        owner: string,
        repo: string,
        pulls: any[],
    ): Promise<PrMetric[]> {
        const results: PrMetric[] = [];

        for (let i = 0; i < pulls.length; i += MetricsService.BATCH_SIZE) {
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

    /**
     * Enriches a single PR: fetches reviews, issue comments,
     * and review comments in parallel, then delegates to the mapper.
     */
    private async enrichSinglePr(
        owner: string,
        repo: string,
        pr: any,
    ): Promise<PrMetric> {
        const prNumber = pr.number;

        const [reviews, issueComments, reviewComments] = await Promise.all([
            this.githubClient
                .paginate(this.githubClient.rest.pulls.listReviews, {
                    owner, repo, pull_number: prNumber, per_page: 100,
                })
                .catch(() => []),
            this.githubClient
                .paginate(this.githubClient.rest.issues.listComments, {
                    owner, repo, issue_number: prNumber, per_page: 100,
                })
                .catch(() => []),
            this.githubClient
                .paginate(this.githubClient.rest.pulls.listReviewComments, {
                    owner, repo, pull_number: prNumber, per_page: 100,
                })
                .catch(() => []),
        ]);

        // Delegate all transformation to the mapper
        return mapToPrMetric({
            pr,
            reviews: reviews as any,
            issueComments: issueComments as any,
            reviewComments: reviewComments as any,
            requiredApprovals: this.env.requiredApprovals,
        });
    }
}
