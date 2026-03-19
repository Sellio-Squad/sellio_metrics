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
     * Search all open PRs for an entire organization.
     * Cached for 10 minutes — multiple simultaneous dashboard users share one result
     * instead of each triggering a separate GitHub API call.
     * Cache is flushed by the webhook handler when a PR is opened/closed/merged.
     */
    async searchOpenPrsForOrg(org: string, perPage: number = 100): Promise<any[]> {
        const cacheKey = `github:open-prs:${org}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        const results = await this.github.paginate(
            this.github.rest.search.issuesAndPullRequests,
            { q: `is:pr is:open org:${org}`, per_page: perPage },
        );

        // Cache for 10 minutes (600s)
        await this.cache.set(cacheKey, results, 600);
        return results;
    }

    /** Flush the open-PRs cache (call after webhook events that change PR state) */
    async flushOpenPrsCache(org: string): Promise<void> {
        try {
            await this.cache.del(`github:open-prs:${org}`);
        } catch { /* ignore */ }
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

    /**
     * Get contributor stats for a repo.
     * Returns GitHub-computed total additions + deletions per contributor
     * (same numbers shown on github.com/org/repo/graphs/contributors).
     *
     * GitHub returns 202 while stats are being computed (can take seconds).
     * We retry up to 6 times with 2-second gaps. In the sync handler we fire
     * this in parallel with other fetches so GitHub has extra time to compute.
     */
    async getContributorStats(owner: string, repo: string): Promise<any[] | null> {
        await this.guard.checkAndWait();
        const MAX_RETRIES = 6;
        for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
            try {
                const res = await this.github.rest.repos.getContributorsStats({ owner, repo });
                if (res.status === 200 && Array.isArray(res.data) && res.data.length > 0) {
                    this.logger.info({ owner, repo, contributors: res.data.length, attempt }, "Contributor stats fetched");
                    return res.data as any[];
                }
                // 202 = still computing — wait and retry
                if (attempt < MAX_RETRIES - 1) {
                    this.logger.debug({ owner, repo, attempt }, "Contributor stats computing (202), retrying...");
                    await new Promise(r => setTimeout(r, 2000));
                }
            } catch (e: any) {
                this.logger.warn({ owner, repo, err: e.message }, "Contributor stats error");
                return null;
            }
        }
        this.logger.warn({ owner, repo }, "Contributor stats still computing after max retries — skipped");
        return null;
    }

    /**
     * List ALL issue/PR comments for a repo in one paginated call.
     * Vastly more efficient than fetching per-PR (avoids the 1000 subrequest limit).
     */
    async listAllIssueComments(owner: string, repo: string): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.issues.listCommentsForRepo,
            { owner, repo, per_page: 100 },
        );
    }

    /**
     * List ALL PR review comments for a repo in one paginated call.
     * Vastly more efficient than fetching per-PR.
     */
    async listAllPRReviewComments(owner: string, repo: string): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.listReviewCommentsForRepo,
            { owner, repo, per_page: 100 },
        );
    }
}
