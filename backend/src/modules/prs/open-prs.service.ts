/**
 * PRs — Open PRs Service (GraphQL)
 *
 * Fetches all open PRs across the org in a single paginated GraphQL query.
 * Reviews and comments are embedded — no per-PR enrichment loop needed.
 *
 * Before:  1 search call + N×4 REST calls per PR (~40+ API calls for 10 open PRs)
 * After:   1-2 GraphQL calls total (~5-15 pts per page)
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { RateLimitGuard } from "../../infra/github/rate-limit-guard";
import type { Logger } from "../../core/logger";
import type { Env } from "../../config/env";
import type { LogsService } from "../logs/logs.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { PrMetric } from "../../core/types";
import { GitHubApiError } from "../../core/errors";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import type { GqlOpenPr } from "../../infra/github/github-graphql.client";
import { toISOWeek, minutesBetween } from "../../core/utils/date";
import { isBot } from "../../lib/bot-filter";

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
     * Fetch all open PRs across the org via GraphQL.
     * Result is cached for 24h; webhooks invalidate on PR events.
     */
    async fetchOpenPrs(org: string): Promise<PrMetric[]> {
        const cacheKey = `github:open_prs:${org}`;

        try {
            const cached = await this.cacheService.get<PrMetric[]>(cacheKey);
            if (cached) {
                this.logger.info({ org }, "Returning open PRs from cache");
                return cached.data;
            }

            this.logger.info({ org }, "Fetching open PRs via GraphQL");

            const gql = new GitHubGraphQLClient(this.github.raw as any, this.logger);
            const { openPrs, totalCostUsed, pagesLoaded } = await gql.searchOpenPRs(org);

            this.logger.info(
                { org, count: openPrs.length, pages: pagesLoaded, totalCostUsed },
                "GraphQL open PRs complete — rate limit cost",
            );

            this.logsService.log(
                `Found ${openPrs.length} open PRs across ${org} (GraphQL: ${totalCostUsed} pts, ${pagesLoaded} pages)`,
                "info",
                "github",
                { org, count: openPrs.length, totalCostUsed, pagesLoaded },
            );

            const mapped = openPrs.map((pr) => this.mapGqlOpenPr(pr));

            // Cache 24h — webhooks will invalidate on PR events
            await this.cacheService.set(cacheKey, mapped, 24 * 60 * 60);
            return mapped;

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

    /**
     * Map a GQL open PR node → PrMetric (matching the shape used by the dashboard).
     */
    private mapGqlOpenPr(pr: GqlOpenPr): PrMetric {
        const approvedReviews = pr.reviews.nodes.filter((r) => r.state === "APPROVED");
        const requiredMet     = approvedReviews.length >= this.requiredApprovals;
        const firstApproval   = approvedReviews[0];
        const requiredMetAt   = requiredMet
            ? (approvedReviews[this.requiredApprovals - 1] as any)?.submittedAt ?? null
            : null;

        const creator = {
            login:      pr.author?.login ?? "",
            id:         0,
            url:        pr.url,
            avatar_url: pr.author?.avatarUrl ?? "",
        };

        // Flatten all comments (timeline + review threads), excluding bots
        const allComments: Array<{ login: string; id: number; date: string; avatarUrl: string }> = [];
        for (const c of pr.comments.nodes) {
            if (!c.author?.login) continue;
            if (isBot(c.author.login)) continue;          // ← filter bot comments
            allComments.push({ login: c.author.login, id: c.databaseId, date: c.createdAt, avatarUrl: c.author.avatarUrl });
        }
        for (const thread of pr.reviewThreads.nodes) {
            for (const c of thread.comments.nodes) {
                if (!c.author?.login) continue;
                if (isBot(c.author.login)) continue;      // ← filter bot review comments
                allComments.push({ login: c.author.login, id: c.databaseId, date: c.createdAt, avatarUrl: c.author.avatarUrl });
            }
        }

        // Also include non-empty review body text as comments (e.g. "Great job Israa" during approval)
        // These live in review.body, NOT in comments or reviewThreads
        let syntheticId = -1;
        for (const review of pr.reviews.nodes) {
            const body = review.body?.trim();
            if (!body || !review.author?.login) continue;
            if (isBot(review.author.login)) continue;
            allComments.push({
                login:     review.author.login,
                id:        syntheticId--,            // negative IDs mark synthetic entries
                date:      review.submittedAt ?? pr.updatedAt,
                avatarUrl: review.author.avatarUrl,
            });
        }

        // Group comments by author
        const byAuthor = new Map<string, { author: { login: string; id: number; url: string; avatar_url: string }; comments: { id: number; created_at: string }[]; }>();
        for (const c of allComments) {
            const existing = byAuthor.get(c.login);
            const entry = { id: c.id, created_at: c.date };
            if (existing) {
                existing.comments.push(entry);
            } else {
                byAuthor.set(c.login, {
                    author: { login: c.login, id: 0, url: "", avatar_url: c.avatarUrl },
                    comments: [entry],
                });
            }
        }

        // Sort each author's comments chronologically
        for (const g of byAuthor.values()) {
            g.comments.sort((a, b) => a.created_at.localeCompare(b.created_at));
        }

        const commentGroups = [...byAuthor.values()].map((g) => ({
            author:          g.author,
            comments:        g.comments,
            first_comment_at: g.comments[0]?.created_at ?? null,
            last_comment_at:  g.comments[g.comments.length - 1]?.created_at ?? null,
            count:           g.comments.length,
        }));

        // Filter bots from approvals too
        const approvals = approvedReviews
            .filter((r) => r.author?.login && !isBot(r.author.login))
            .map((r) => ({
                reviewer:     { login: r.author?.login ?? "", id: 0, url: "", avatar_url: r.author?.avatarUrl ?? "" },
                submitted_at: r.submittedAt ?? pr.updatedAt,
                commit_id:    "",
            }));

        return {
            pr_number:                          pr.number,
            url:                                pr.url,
            title:                              pr.title,
            opened_at:                          pr.createdAt,
            head_ref:                           "",
            base_ref:                           "",
            creator,
            assignees:                          [creator],
            comments:                           commentGroups,
            approvals,
            required_approvals:                 this.requiredApprovals,
            first_approved_at:                  firstApproval ? (firstApproval as any).submittedAt ?? null : null,
            time_to_first_approval_minutes:     minutesBetween(pr.createdAt, requiredMet ? requiredMetAt : null),
            required_approvals_met_at:          requiredMetAt,
            time_to_required_approvals_minutes: minutesBetween(pr.createdAt, requiredMetAt),
            closed_at:                          null,
            merged_at:                          null,
            merged_by:                          null,
            week:                               toISOWeek(pr.createdAt),
            status:                             requiredMet ? "approved" : "pending",
            labels:                             [],
            milestone:                          null,
            draft:                              false,
            review_requests:                    [],
            files_changed:                      [],
            diff_stats: {
                additions:     pr.additions,
                deletions:     pr.deletions,
                changed_files: pr.changedFiles,
            },
        };
    }
}
