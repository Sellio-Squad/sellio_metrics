/**
 * Sellio Metrics Backend — Cached GitHub Client
 *
 * Cache-first wrapper around the raw GitHubClient.
 * IMPORTANT: Only the final RESULT is cached (in MetricsService).
 * Raw GitHub data (PR lists, reviews, comments) is fetched fresh
 * every time there is a result cache miss — no intermediate KV writes
 * for individual PRs. This preserves the precious KV write quota.
 */

import type { GitHubClient } from "./github.client";
import type { CacheService } from "../cache/cache.service";
import type { RateLimitGuard } from "./rate-limit-guard";
import type { Logger } from "../../core/logger";

// ─── Service ────────────────────────────────────────────────

export class CachedGitHubClient {
    private readonly github: GitHubClient;
    private readonly cache: CacheService;
    private readonly membersKv: CacheService;
    private readonly guard: RateLimitGuard;
    private readonly logger: Logger;

    constructor({
        githubClient,
        cacheService,
        membersKvCache,
        rateLimitGuard,
        logger,
    }: {
        githubClient: GitHubClient;
        cacheService: CacheService;
        membersKvCache: CacheService;
        rateLimitGuard: RateLimitGuard;
        logger: Logger;
    }) {
        this.github = githubClient;
        this.cache = cacheService;
        this.membersKv = membersKvCache;
        this.guard = rateLimitGuard;
        this.logger = logger.child({ module: "cached-github" });
    }

    // ─── Public API ─────────────────────────────────────────

    /**
     * List repos for an org — cached for 24 hours (single write).
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
        await this.cache.set(cacheKey, repos, 24 * 60 * 60);
        return repos;
    }

    /**
     * List all members of an organization — cached permanently.
     * Webhook handler flushes this cache on changes.
     */
    async listOrgMembers(org: string): Promise<any[]> {
        const cacheKey = `github:org-members:${org}`;
        const cached = await this.membersKv.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        const members = await this.github.paginate(
            this.github.rest.orgs.listMembers,
            { org, filter: "all", role: "all", per_page: 100 }
        );
        await this.membersKv.set(cacheKey, members);
        return members;
    }

    /**
     * List all PRs — NO intermediate cache, result will be cached at the
     * MetricsService level as a single computed result key.
     */
    async listPulls(
        owner: string,
        repo: string,
        state: "all" | "open" | "closed",
        perPage: number,
    ): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.list,
            { owner, repo, state, sort: "created", direction: "desc", per_page: perPage },
        );
    }

    /**
     * Get full PR details — NO intermediate cache.
     */
    async getPull(owner: string, repo: string, pullNumber: number, _isOpen: boolean): Promise<any> {
        const response = await this.github.rest.pulls.get({ owner, repo, pull_number: pullNumber });
        if (response?.headers) this.guard.updateFromHeaders(response.headers as Record<string, string | undefined>);
        return response.data;
    }

    /**
     * List reviews for a PR — NO intermediate cache.
     */
    async listReviews(owner: string, repo: string, pullNumber: number, _isOpen: boolean): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.listReviews,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );
    }

    /**
     * List issue comments — NO intermediate cache.
     */
    async listIssueComments(owner: string, repo: string, issueNumber: number, _isOpen: boolean): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.issues.listComments,
            { owner, repo, issue_number: issueNumber, per_page: 100 },
        );
    }

    /**
     * List review comments — NO intermediate cache.
     */
    async listReviewComments(owner: string, repo: string, pullNumber: number, _isOpen: boolean): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.listReviewComments,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );
    }

    /** Expose raw client for uncached operations. */
    get raw(): GitHubClient {
        return this.github;
    }
}
