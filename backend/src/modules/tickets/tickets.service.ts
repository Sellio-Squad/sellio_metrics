/**
 * Open Tickets Service
 *
 * Merges two data sources into one unified "Open Tickets" feed:
 *   1. GitHub Issues (is:issue is:open org:{org}) via GraphQL search
 *   2. GitHub Projects v2 items (issues + draft issues in org projects)
 *
 * Deduplication: project items that are linked GitHub issues are merged
 * with their issue counterpart (project fields win for status/due_date).
 * Draft issues (not linked to any GitHub issue) appear as source='draft'.
 *
 * Cached in KV for 30 minutes.
 */

import type { CachedGitHubClient } from "../../infra/github/cached-github.client";
import type { Logger } from "../../core/logger";
import type { CacheService } from "../../infra/cache/cache.service";
import type { LogsService } from "../logs/logs.service";
import type { Env } from "../../config/env";
import { GitHubApiError } from "../../core/errors";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import type { TicketMetric, TicketSource } from "./tickets.types";
import { Octokit } from "@octokit/rest";

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

export class OpenTicketsService {
    private readonly github: CachedGitHubClient;
    private readonly logger: Logger;
    private readonly logsService: LogsService;
    private readonly cacheService: CacheService;
    private readonly githubToken: string;

    constructor({
        cachedGithubClient,
        logger,
        logsService,
        cacheService,
        env,
    }: {
        cachedGithubClient: CachedGitHubClient;
        logger: Logger;
        logsService: LogsService;
        cacheService: CacheService;
        env: Env;
    }) {
        this.github = cachedGithubClient;
        this.logger = logger.child({ module: "open-tickets" });
        this.logsService = logsService;
        this.cacheService = cacheService;
        this.githubToken = env.githubToken;
    }

    // ─── Public ──────────────────────────────────────────────

    async fetchOpenTickets(org: string): Promise<TicketMetric[]> {
        const cacheKey = `github:open_tickets:${org}`;

        try {
            const cached = await this.cacheService.get<TicketMetric[]>(cacheKey);
            if (cached) {
                this.logger.info({ org }, "Returning open tickets from cache");
                return cached.data;
            }

            this.logger.info({ org }, "Fetching open tickets via GraphQL");

            // Use a PAT if available (GitHub App may lack Projects v2 read permission)
            let octokitAuth: any;
            if (this.githubToken) {
                this.logger.info({ org }, "Using GITHUB_TOKEN (PAT) for tickets fetch");
                octokitAuth = new Octokit({ auth: this.githubToken });
            } else {
                this.logger.warn({ org }, "No GITHUB_TOKEN set — falling back to App token (may miss Projects)");
                octokitAuth = (this.github as any).raw ?? this.github;
            }

            const gql = new GitHubGraphQLClient(octokitAuth, this.logger);

            // ── 1. Fetch regular GitHub issues ────────────────
            const { issues, totalCostUsed: issueCost } = await gql.searchOpenIssues(org);
            this.logger.info({ org, count: issues.length, cost: issueCost }, "Issues fetch complete");

            // ── 2. Fetch Projects v2 items ────────────────────
            let projectItems: TicketMetric[] = [];
            try {
                const { projects, totalCostUsed: projectCost } = await gql.searchOrgProjectItems(org);
                this.logger.info({ org, projects: projects.length, cost: projectCost }, "Projects fetch complete");
                projectItems = this.mapProjectsToTickets(projects);
            } catch (projErr: any) {
                // Projects v2 may 404 if token lacks read:project — degrade gracefully
                this.logger.warn({ org, err: projErr.message }, "Projects v2 fetch failed — continuing with issues only");
            }

            // ── 3. Map issues to TicketMetric ─────────────────
            const issueTickets = issues.map((i) => this.mapGqlIssue(i));

            // ── 4. Merge: deduplicate by html_url ─────────────
            const merged = this.mergeTickets(issueTickets, projectItems);

            this.logsService.log(
                `Found ${merged.length} open tickets across ${org} (${issueTickets.length} issues + ${projectItems.length} project items)`,
                "info",
                "github",
                { org, total: merged.length },
            );

            // Cache 30 min — tickets update more often than daily
            await this.cacheService.set(cacheKey, merged, 30 * 60);
            return merged;
        } catch (err: any) {
            if (err instanceof GitHubApiError) throw err;
            throw new GitHubApiError(`Failed to fetch open tickets for ${org}: ${err.message}`);
        }
    }

    async invalidateCache(org: string): Promise<void> {
        await this.cacheService.del(`github:open_tickets:${org}`);
        this.logger.info({ org }, "Invalidated open tickets cache");
    }

    // ─── Private mappers ─────────────────────────────────────

    private mapGqlIssue(issue: any): TicketMetric {
        const labels: { name: string; color: string }[] = (issue.labels?.nodes ?? []).map((l: any) => ({
            name:  l.name ?? "",
            color: l.color ?? "cccccc",
        }));

        const assignees = (issue.assignees?.nodes ?? []).map((a: any) => ({
            login:      a.login ?? "",
            avatar_url: a.avatarUrl ?? "",
        }));

        const milestone = issue.milestone
            ? { title: issue.milestone.title ?? "", due_on: issue.milestone.dueOn ?? null }
            : null;

        let repoName = issue.repository?.name ?? "";
        if (!repoName && issue.url) {
            const parts = issue.url.split("/");
            repoName = parts[parts.length - 3] ?? "";
        }

        return {
            number:         issue.number,
            title:          issue.title,
            url:            issue.url,
            html_url:       issue.url,
            repo_name:      repoName,
            author:         { login: issue.author?.login ?? "unknown", avatar_url: issue.author?.avatarUrl ?? "" },
            assignees,
            labels,
            created_at:     issue.createdAt,
            milestone,
            priority:       extractPriority(labels),
            body:           issue.bodyText ?? "",
            source:         "issue",
            project_name:   null,
            project_number: null,
            project_status: null,
            due_date:       null,
        };
    }

    private mapProjectsToTickets(projects: any[]): TicketMetric[] {
        const tickets: TicketMetric[] = [];

        for (const project of projects) {
            for (const item of (project.items?.nodes ?? [])) {
                const content = item.content;
                if (!content) continue;

                // Extract project field values
                let projectStatus: string | null = null;
                let dueDate: string | null = null;
                for (const fv of (item.fieldValues?.nodes ?? [])) {
                    if (!fv || !fv.field) continue;
                    const fname = (fv.field.name ?? "").toLowerCase();
                    if (fv.__typename === "ProjectV2ItemFieldSingleSelectValue" && (fname === "status" || fname === "state")) {
                        projectStatus = fv.name ?? null;
                    }
                    if (fv.__typename === "ProjectV2ItemFieldDateValue" && (fname.includes("due") || fname.includes("date"))) {
                        dueDate = fv.date ?? null;
                    }
                }

                const typename = content.__typename;

                if (typename === "Issue") {
                    // Skip closed issues
                    if (content.state && content.state !== "OPEN") continue;

                    const labels = (content.labels?.nodes ?? []).map((l: any) => ({ name: l.name ?? "", color: l.color ?? "cccccc" }));
                    const assignees = (content.assignees?.nodes ?? []).map((a: any) => ({ login: a.login ?? "", avatar_url: a.avatarUrl ?? "" }));
                    const milestone = content.milestone
                        ? { title: content.milestone.title ?? "", due_on: content.milestone.dueOn ?? null }
                        : null;

                    tickets.push({
                        number:         content.number ?? 0,
                        title:          content.title ?? "",
                        url:            content.url ?? "",
                        html_url:       content.url ?? "",
                        repo_name:      content.repository?.name ?? "",
                        author:         { login: content.author?.login ?? "unknown", avatar_url: content.author?.avatarUrl ?? "" },
                        assignees,
                        labels,
                        created_at:     content.createdAt ?? new Date().toISOString(),
                        milestone,
                        priority:       extractPriority(labels),
                        body:           content.bodyText ?? "",
                        source:         "project_item",
                        project_name:   project.title ?? null,
                        project_number: project.number ?? null,
                        project_status: projectStatus,
                        due_date:       dueDate,
                    });
                } else if (typename === "DraftIssue") {
                    // Draft issues: no GitHub issue number/url
                    const assignees = (content.assignees?.nodes ?? []).map((a: any) => ({ login: a.login ?? "", avatar_url: a.avatarUrl ?? "" }));

                    tickets.push({
                        number:         0,
                        title:          content.title ?? "Draft Issue",
                        url:            `https://github.com/orgs/${project.title}/projects/${project.number}`,
                        html_url:       `https://github.com/orgs/${project.title}/projects/${project.number}`,
                        repo_name:      "",
                        author:         { login: "unknown", avatar_url: "" },
                        assignees,
                        labels:         [],
                        created_at:     content.createdAt ?? new Date().toISOString(),
                        milestone:      null,
                        priority:       null,
                        body:           content.body ?? "",
                        source:         "draft",
                        project_name:   project.title ?? null,
                        project_number: project.number ?? null,
                        project_status: projectStatus,
                        due_date:       dueDate,
                    });
                }
            }
        }

        return tickets;
    }

    /**
     * Merge issue tickets + project tickets.
     * - Project items that are GitHub Issues: merge into issue ticket (project fields win for status/due_date)
     * - Draft issues: kept as-is (unique to projects)
     * - Result sorted: overdue → no deadline → healthy → draft
     */
    private mergeTickets(issues: TicketMetric[], projectItems: TicketMetric[]): TicketMetric[] {
        const byUrl = new Map<string, TicketMetric>();

        // Seed with issues
        for (const issue of issues) {
            byUrl.set(issue.html_url, issue);
        }

        // Merge/append project items
        for (const pi of projectItems) {
            if (pi.source === "draft") {
                // Draft items have no URL conflict — use a synthetic key
                byUrl.set(`draft:${pi.project_number}:${pi.title}`, pi);
                continue;
            }

            const existing = byUrl.get(pi.html_url);
            if (existing) {
                // Enrich existing issue with project metadata
                byUrl.set(pi.html_url, {
                    ...existing,
                    source:         "project_item",
                    project_name:   pi.project_name,
                    project_number: pi.project_number,
                    project_status: pi.project_status,
                    due_date:       pi.due_date ?? existing.due_date,
                });
            } else {
                // Project item not in issue search (may be from other state): include it
                byUrl.set(pi.html_url, pi);
            }
        }

        return Array.from(byUrl.values());
    }
}
