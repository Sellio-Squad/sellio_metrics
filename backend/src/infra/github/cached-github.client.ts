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

export interface SlimRepo {
    id: number;
    name: string;
    full_name: string;
    html_url: string;
    description: string | null;
    created_at: string;
    pushed_at: string;
    language: string | null;
    private: boolean;
    fork: boolean;
}

export interface SlimMember {
    login: string;
    avatar_url: string;
}

export interface SlimPr {
    id: number;
    number: number;
    title: string;
    state: string;
    user: { login: string } | null;
    html_url: string;
    head: { sha: string; ref: string };
    additions: number;
    deletions: number;
    changed_files: number;
    created_at: string;
    merged_at: string | null;
    closed_at: string | null;
    body: string | null;
}

export interface SlimCommit {
    sha: string;
    stats?: { additions?: number; deletions?: number; total?: number };
    commit: { message: string; author: any };
    author: any;
    html_url: string;
}

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
    async listOrgRepos(org: string): Promise<SlimRepo[]> {
        const cacheKey = `github:repos:${org}`;
        const cached = await this.cache.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        const repos = await this.github.paginate(
            this.github.rest.repos.listForOrg,
            { org, type: "all", sort: "updated", per_page: 100 },
        );

        // Cache only the fields needed by sync/repos routes — not the hundreds of URL fields
        const slim: SlimRepo[] = repos.map((r: any) => ({
            id:          r.id,
            name:        r.name,
            full_name:   r.full_name,
            html_url:    r.html_url,
            description: r.description ?? null,
            created_at:  r.created_at,
            pushed_at:   r.pushed_at,
            language:    r.language ?? null,
            private:     r.private,
            fork:        r.fork,
        }));
        await this.cache.set(cacheKey, slim, 24 * 60 * 60);
        return slim;
    }

    /**
     * List all members of an organization — cached permanently.
     * Webhook handler flushes this cache on changes.
     */
    async listOrgMembers(org: string): Promise<SlimMember[]> {
        const cacheKey = `github:org-members:${org}`;
        const cached = await this.membersKv.get<any[]>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        const members = await this.github.paginate(
            this.github.rest.orgs.listMembers,
            { org, filter: "all", role: "all", per_page: 100 }
        );

        // Cache only login + avatar_url — not all 30+ URL fields per member
        const slim: SlimMember[] = members.map((m: any) => ({ login: m.login, avatar_url: m.avatar_url }));
        await this.membersKv.set(cacheKey, slim);
        return slim;
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
     * NOTE: Caching is handled by OpenPrsService.fetchOpenPrs (24h TTL + webhook invalidation).
     * This method is intentionally uncached — do not add caching here.
     */
    async searchOpenPrsForOrg(org: string, perPage: number = 100): Promise<any[]> {
        await this.guard.checkAndWait();
        const results = await this.github.paginate(
            this.github.rest.search.issuesAndPullRequests,
            { q: `is:pr is:open org:${org}`, per_page: perPage },
        );
        return results;
    }

    /**
     * Get full PR details — includes additions, deletions, changed_files, body.
     *
     * IMPORTANT: Always calls checkAndWait() internally so callers don't
     * need to manage rate limits themselves.
     *
     * GitHub's secondary rate limit (abuse detection) fires based on
     * request *frequency*, not just remaining quota. We add a minimum
     * 300 ms gap between calls to stay inside GitHub's tolerated burst.
     */
    async getPull(owner: string, repo: string, pullNumber: number): Promise<SlimPr> {
        const MAX_RETRIES = 3;
        let attempt = 0;

        while (attempt < MAX_RETRIES) {
            try {
                await this.guard.checkAndWait();

                // Minimum inter-request delay to avoid secondary rate limit (abuse detection).
                // 300ms = ~3 req/s which is well within GitHub's undocumented ~5 req/s limit.
                // If attempt > 0, we apply exponential backoff.
                const delayMs = attempt === 0 ? 300 : 1000 * Math.pow(2, attempt);
                await new Promise((r) => setTimeout(r, delayMs));

                const response = await this.github.rest.pulls.get({ owner, repo, pull_number: pullNumber });
                if (response?.headers) {
                    this.guard.updateFromHeaders(response.headers as Record<string, string | undefined>);
                }
                
                const data = response.data;
                const additions = data.additions ?? 0;
                const deletions = data.deletions ?? 0;
                const changedFiles = data.changed_files ?? 0;
                
                // GitHub can sometimes lag in computing the diffs in the background.
                // If changed_files > 0 but additions+deletions == 0, we retry.
                if (changedFiles > 0 && additions === 0 && deletions === 0 && attempt < MAX_RETRIES - 1) {
                    this.logger.warn({ prNumber: pullNumber, attempt }, "getPull returned zero diff but changed_files > 0 — retrying (diff computation lag)");
                    attempt++;
                    continue;
                }

                return data as SlimPr;
            } catch (error: any) {
                const status = error.status || error.response?.status;
                const isSecondaryRateLimit = status === 403 && error.message?.toLowerCase().includes("secondary rate limit");
                const isServerError = status >= 500 && status < 600;
                
                if ((isSecondaryRateLimit || isServerError) && attempt < MAX_RETRIES - 1) {
                    this.logger.warn(
                        { prNumber: pullNumber, attempt, status, errMsg: error.message },
                        "getPull encountered transient error — retrying"
                    );
                    attempt++;
                    continue;
                }
                
                this.logger.error(
                    { prNumber: pullNumber, status, errMsg: error.message },
                    "getPull failed permanently after retries"
                );
                throw error;
            }
        }
        
        throw new Error(`Failed to fetch PR #${pullNumber} after ${MAX_RETRIES} attempts`);
    }

    /**
     * List reviews for a PR — NO intermediate cache.
     */
    async listReviews(owner: string, repo: string, pullNumber: number): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.listReviews,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );
    }

    /**
     * List issue comments — NO intermediate cache.
     */
    async listIssueComments(owner: string, repo: string, issueNumber: number): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.issues.listComments,
            { owner, repo, issue_number: issueNumber, per_page: 100 },
        );
    }

    /**
     * List review comments — NO intermediate cache.
     */
    async listReviewComments(owner: string, repo: string, pullNumber: number): Promise<any[]> {
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
     * Get a user's full profile — includes name (display_name) and created_at (joined_at).
     * Cached for 24h since profiles rarely change.
     */
    async getUser(login: string): Promise<any> {
        const cacheKey = `github:user:${login}`;
        const cached = await this.cache.get<any>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        const response = await this.github.rest.users.getByUsername({ username: login });
        if (response?.headers) this.guard.updateFromHeaders(response.headers as Record<string, string | undefined>);
        await this.cache.set(cacheKey, response.data, 24 * 60 * 60);
        return response.data;
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

    /**
     * List files changed in a PR — includes patch diffs, status, additions/deletions per file.
     * No caching — result is used in one-shot reviews.
     */
    async listPrFiles(owner: string, repo: string, pullNumber: number): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.pulls.listFiles,
            { owner, repo, pull_number: pullNumber, per_page: 100 },
        );
    }

    /**
     * List ALL commits for a repo — used for historical commit sync.
     * Paginates automatically. Optional `since` ISO date to limit scope.
     */
    async listCommits(owner: string, repo: string, opts: { since?: string } = {}): Promise<any[]> {
        await this.guard.checkAndWait();
        return this.github.paginate(
            this.github.rest.repos.listCommits,
            { owner, repo, per_page: 100, ...(opts.since ? { since: opts.since } : {}) },
        );
    }

    /**
     * Get a single commit with full stats (additions/deletions per file).
     * Cached for 24h since commit data is immutable.
     */
    async getCommit(owner: string, repo: string, ref: string): Promise<SlimCommit> {
        const cacheKey = `github:commit:${owner}/${repo}/${ref}`;
        const cached = await this.cache.get<any>(cacheKey);
        if (cached) return cached.data;

        await this.guard.checkAndWait();
        await new Promise((r) => setTimeout(r, 300)); // throttle

        const response = await this.github.rest.repos.getCommit({ owner, repo, ref });
        if (response?.headers) this.guard.updateFromHeaders(response.headers as Record<string, string | undefined>);

        const slim: SlimCommit = {
            sha: response.data.sha,
            stats: response.data.stats,
            commit: {
                message: response.data.commit.message,
                author: response.data.commit.author,
            },
            author: response.data.author,
            html_url: response.data.html_url,
        };
        await this.cache.set(cacheKey, slim, 24 * 60 * 60);
        return slim;
    }
}
