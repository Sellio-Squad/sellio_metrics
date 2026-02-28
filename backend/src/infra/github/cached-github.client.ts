/**
 * Sellio Metrics Backend — Cached GitHub Client
 *
 * Single Responsibility: Cache-first wrapper around the raw GitHubClient.
 *
 * This class sits between services and Octokit. Its only concern is
 * checking Redis before hitting GitHub, and storing responses with
 * appropriate TTLs.
 *
 * It does NOT record observability events — that's handled by:
 *   - CacheService.getStats()  → cache hit/miss/error counters
 *   - tracked-github.client    → per-request observability via Octokit hooks
 */

import type { GitHubClient } from "./github.client";
import type { CacheService } from "../cache/cache.service";
import type { RateLimitGuard } from "./rate-limit-guard";
import type { Logger } from "../../core/logger";

// ─── TTL Constants (seconds) ────────────────────────────────

const TTL = {
    /** Merged/closed PRs — immutable, cache aggressively. */
    PR_CLOSED: 24 * 60 * 60,       // 24 hours
    /** Open PR details — changes frequently. */
    PR_OPEN: 2 * 60,               // 2 minutes
    /** Reviews on a merged PR — won't change. */
    REVIEWS_CLOSED: 24 * 60 * 60,  // 24 hours
    /** Reviews on an open PR — may get new reviews. */
    REVIEWS_OPEN: 5 * 60,          // 5 minutes
    /** Comments on a merged PR. */
    COMMENTS_CLOSED: 24 * 60 * 60, // 24 hours
    /** Comments on an open PR — active discussion. */
    COMMENTS_OPEN: 5 * 60,         // 5 minutes
    /** Organization repo list — rarely changes. */
    REPO_LIST: 24 * 60 * 60,       // 24 hours
    /** PR list (paginated) — moderate freshness. */
    PR_LIST: 3 * 60,               // 3 minutes
} as const;

// ─── Service ────────────────────────────────────────────────

export class CachedGitHubClient {
    private readonly github: GitHubClient;
    private readonly cache: CacheService;
    private readonly guard: RateLimitGuard;
    private readonly logger: Logger;

    constructor({
        githubClient,
        cacheService,
        rateLimitGuard,
        logger,
    }: {
        githubClient: GitHubClient;
        cacheService: CacheService;
        rateLimitGuard: RateLimitGuard;
        logger: Logger;
    }) {
        this.github = githubClient;
        this.cache = cacheService;
        this.guard = rateLimitGuard;
        this.logger = logger.child({ module: "cached-github" });
    }

    // ─── Public API ─────────────────────────────────────────

    /**
     * List repos for an org — cached for 24 hours.
     */
    async listOrgRepos(org: string): Promise<any[]> {
        const cacheKey = `github:repos:${org}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();

        const repos = await this.github.paginate(
            this.github.rest.repos.listForOrg,
            { org, type: "all", sort: "updated", per_page: 100 },
        );

        await this.cache.set(cacheKey, repos, TTL.REPO_LIST);
        return repos;
    }

    /**
     * List all PRs for a repo — cached for 3 minutes.
     */
    async listPulls(
        owner: string,
        repo: string,
        state: "all" | "open" | "closed",
        perPage: number,
    ): Promise<any[]> {
        const cacheKey = `github:pulls:${owner}/${repo}:${state}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();

        const pulls = await this.github.paginate(
            this.github.rest.pulls.list,
            { owner, repo, state, sort: "created", direction: "desc", per_page: perPage },
        );

        await this.cache.set(cacheKey, pulls, TTL.PR_LIST);
        return pulls;
    }

    /**
     * Get full PR details — TTL depends on whether the PR is open or closed.
     */
    async getPull(owner: string, repo: string, pullNumber: number, isOpen: boolean): Promise<any> {
        const cacheKey = `github:pull:${owner}/${repo}:${pullNumber}`;
        const cached = await this.cache.get<any>(cacheKey);
        if (cached) return cached.data;

        const response = await this.github.rest.pulls.get({
            owner,
            repo,
            pull_number: pullNumber,
        });

        this.updateGuardFromResponse(response);
        await this.cache.set(cacheKey, response.data, isOpen ? TTL.PR_OPEN : TTL.PR_CLOSED);
        return response.data;
    }

    /**
     * List reviews for a PR — TTL depends on PR state.
     */
    async listReviews(
        owner: string,
        repo: string,
        pullNumber: number,
        isOpen: boolean,
    ): Promise<any[]> {
        const cacheKey = `github:reviews:${owner}/${repo}:${pullNumber}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        const reviews = await this.github.paginate(
            this.github.rest.pulls.listReviews,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );

        this.updateGuardFromPaginateResponse(reviews);
        await this.cache.set(cacheKey, reviews, isOpen ? TTL.REVIEWS_OPEN : TTL.REVIEWS_CLOSED);
        return reviews;
    }

    /**
     * List issue comments — TTL depends on PR state.
     */
    async listIssueComments(
        owner: string,
        repo: string,
        issueNumber: number,
        isOpen: boolean,
    ): Promise<any[]> {
        const cacheKey = `github:issue-comments:${owner}/${repo}:${issueNumber}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        const comments = await this.github.paginate(
            this.github.rest.issues.listComments,
            { owner, repo, issue_number: issueNumber, per_page: 100 },
        );

        this.updateGuardFromPaginateResponse(comments);
        await this.cache.set(cacheKey, comments, isOpen ? TTL.COMMENTS_OPEN : TTL.COMMENTS_CLOSED);
        return comments;
    }

    /**
     * List review comments — TTL depends on PR state.
     */
    async listReviewComments(
        owner: string,
        repo: string,
        pullNumber: number,
        isOpen: boolean,
    ): Promise<any[]> {
        const cacheKey = `github:review-comments:${owner}/${repo}:${pullNumber}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        const comments = await this.github.paginate(
            this.github.rest.pulls.listReviewComments,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );

        this.updateGuardFromPaginateResponse(comments);
        await this.cache.set(cacheKey, comments, isOpen ? TTL.COMMENTS_OPEN : TTL.COMMENTS_CLOSED);
        return comments;
    }

    /**
     * Expose the raw GitHub client for uncached operations.
     */
    get raw(): GitHubClient {
        return this.github;
    }

    // ─── Private Helpers ────────────────────────────────────

    private updateGuardFromResponse(response: any): void {
        if (response?.headers) {
            this.guard.updateFromHeaders(response.headers);
        }
    }

    private updateGuardFromPaginateResponse(_data: any): void {
        // Octokit paginate doesn't directly expose headers on the result array.
        // The tracked-github.client hooks catch rate limit headers from each
        // individual request, and we can rely on that for the guard's state.
    }
}
