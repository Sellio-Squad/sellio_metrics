/**
 * Open Issues Service
 *
 * Fetches all open issues (NOT PRs) across the org using
 * GitHub's GraphQL search API: `is:issue is:open org:{org}`.
 *
 * Cached in KV for 1 hour. Webhook invalidation can call invalidateCache().
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { Logger } from "../../core/logger";
import type { CacheService } from "../../infra/cache/cache.service";
import type { LogsService } from "../logs/logs.service";
import { GitHubApiError } from "../../core/errors";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import type { IssueMetric } from "./issues.types";

const PRIORITY_LABELS: Record<string, string> = {
    critical: "critical",
    "p0":     "critical",
    urgent:   "critical",
    high:     "high",
    "p1":     "high",
    medium:   "medium",
    "p2":     "medium",
    low:      "low",
    "p3":     "low",
};

function extractPriority(labels: { name: string }[]): string | null {
    for (const label of labels) {
        const lower = label.name.toLowerCase();
        for (const [keyword, priority] of Object.entries(PRIORITY_LABELS)) {
            if (lower === keyword || lower.includes(keyword)) {
                return priority;
            }
        }
    }
    return null;
}

export class OpenIssuesService {
    private readonly github: CachedGitHubClient;
    private readonly logger: Logger;
    private readonly logsService: LogsService;
    private readonly cacheService: CacheService;

    constructor({
        cachedGithubClient,
        logger,
        logsService,
        cacheService,
    }: {
        cachedGithubClient: CachedGitHubClient;
        logger: Logger;
        logsService: LogsService;
        cacheService: CacheService;
    }) {
        this.github = cachedGithubClient;
        this.logger = logger.child({ module: "open-issues" });
        this.logsService = logsService;
        this.cacheService = cacheService;
    }

    /**
     * Fetch all open issues across the org via GraphQL.
     * Cached 1 hour — covers sprint-level monitoring granularity.
     */
    async fetchOpenIssues(org: string): Promise<IssueMetric[]> {
        const cacheKey = `github:open_issues:${org}`;

        try {
            const cached = await this.cacheService.get<IssueMetric[]>(cacheKey);
            if (cached) {
                this.logger.info({ org }, "Returning open issues from cache");
                return cached.data;
            }

            this.logger.info({ org }, "Fetching open issues via GraphQL");

            const gql = new GitHubGraphQLClient(this.github.raw as any, this.logger);
            const { issues, totalCostUsed, pagesLoaded } = await gql.searchOpenIssues(org);

            this.logger.info(
                { org, count: issues.length, pages: pagesLoaded, totalCostUsed },
                "GraphQL open issues complete — rate limit cost",
            );

            this.logsService.log(
                `Found ${issues.length} open issues across ${org} (GraphQL: ${totalCostUsed} pts, ${pagesLoaded} pages)`,
                "info",
                "github",
                { org, count: issues.length, totalCostUsed, pagesLoaded },
            );

            const mapped = issues.map((issue) => this.mapGqlIssue(issue));

            // Cache 1h — issues change more frequently than PRs
            await this.cacheService.set(cacheKey, mapped, 60 * 60);
            return mapped;
        } catch (err: any) {
            if (err instanceof GitHubApiError) throw err;
            throw new GitHubApiError(`Failed to fetch open issues for ${org}: ${err.message}`);
        }
    }

    async invalidateCache(org: string): Promise<void> {
        await this.cacheService.del(`github:open_issues:${org}`);
        this.logger.info({ org }, "Invalidated open issues cache");
    }

    // ─── Private ─────────────────────────────────────────────

    private mapGqlIssue(issue: any): IssueMetric {
        const labels: { name: string; color: string }[] = (issue.labels?.nodes ?? []).map((l: any) => ({
            name:  l.name ?? "",
            color: l.color ?? "cccccc",
        }));

        const assignees: { login: string; avatar_url: string }[] = (issue.assignees?.nodes ?? []).map((a: any) => ({
            login:      a.login ?? "",
            avatar_url: a.avatarUrl ?? "",
        }));

        const milestone = issue.milestone
            ? {
                title:  issue.milestone.title ?? "",
                due_on: issue.milestone.dueOn ?? null,
              }
            : null;

        // Repo name from repository.nameWithOwner, fallback parse from url
        let repoName = issue.repository?.name ?? "";
        if (!repoName && issue.url) {
            const parts = issue.url.split("/");
            repoName = parts[parts.length - 3] ?? "";
        }

        return {
            number:     issue.number,
            title:      issue.title,
            url:        issue.url,
            html_url:   issue.url,
            repo_name:  repoName,
            author:     {
                login:      issue.author?.login ?? "unknown",
                avatar_url: issue.author?.avatarUrl ?? "",
            },
            assignees,
            labels,
            created_at: issue.createdAt,
            milestone,
            priority:   extractPriority(labels),
            body:       issue.bodyText ?? "",
        };
    }
}
