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
import type { PrMetric, LeaderboardEntry } from "../../core/types";
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

    /**
     * Calculate leaderboard entries from a list of PRs.
     * Logic is hosted on backend so it can be updated live.
     */
    calculateLeaderboard(prs: PrMetric[]): LeaderboardEntry[] {
        const weights = {
            prsCreated: 3,
            prsMerged: 2,
            reviewsGiven: 0, // Removed from points as requested
            commentsGiven: 1,
        };

        const scores = new Map<string, {
            avatarUrl: string | null;
            prsCreated: number;
            prsMerged: number;
            reviewsGiven: number;
            commentsGiven: number;
        }>();

        const getOrCreate = (login: string) => {
            let entry = scores.get(login);
            if (!entry) {
                entry = { avatarUrl: null, prsCreated: 0, prsMerged: 0, reviewsGiven: 0, commentsGiven: 0 };
                scores.set(login, entry);
            }
            return entry;
        };

        for (const pr of prs) {
            const creator = pr.creator.login;
            const cEntry = getOrCreate(creator);
            cEntry.prsCreated++;
            cEntry.avatarUrl ??= pr.creator.avatar_url;
            if (pr.status === "merged") cEntry.prsMerged++;

            for (const approval of pr.approvals) {
                const reviewer = approval.reviewer.login;
                if (reviewer === creator) continue;
                const rEntry = getOrCreate(reviewer);
                rEntry.reviewsGiven++;
                rEntry.avatarUrl ??= approval.reviewer.avatar_url;
            }

            for (const comment of pr.comments) {
                const commenter = comment.author.login;
                const coEntry = getOrCreate(commenter);
                coEntry.commentsGiven++;
                coEntry.avatarUrl ??= comment.author.avatar_url;
            }
        }

        return Array.from(scores.entries()).map(([login, a]) => {
            const totalScore =
                a.prsCreated * weights.prsCreated +
                a.prsMerged * weights.prsMerged +
                a.reviewsGiven * weights.reviewsGiven +
                a.commentsGiven * weights.commentsGiven;

            return {
                developer: login,
                avatarUrl: a.avatarUrl,
                prsCreated: a.prsCreated,
                prsMerged: a.prsMerged,
                reviewsGiven: a.reviewsGiven,
                commentsGiven: a.commentsGiven,
                totalScore,
            };
        }).sort((a, b) => b.totalScore - a.totalScore);
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

    private async enrichSinglePr(
        owner: string,
        repo: string,
        pr: any,
    ): Promise<PrMetric> {
        const prNumber = pr.number;

        const [fullPrResponse, reviews, issueComments, reviewComments] = await Promise.all([
            this.githubClient.rest.pulls.get({
                owner, repo, pull_number: prNumber
            }).catch(() => ({ data: pr })),
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

        const fullPr = fullPrResponse.data;

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
