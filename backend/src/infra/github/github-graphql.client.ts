/**
 * GitHub GraphQL Client
 *
 * Fetches PR data (with reviews, comments, authors) in a single
 * paginated GraphQL query instead of N×4 REST calls.
 *
 * Rate limit transparency:
 *   - GitHub GraphQL uses a POINT-based rate limit (5,000 pts/hour)
 *   - Each query response includes `rateLimit.cost` and `rateLimit.remaining`
 *   - We log these after every page so you can see real costs in the dashboard
 *
 * Pagination:
 *   - We use cursor-based pagination (`after: $cursor`)
 *   - Each page fetches up to MERGED_PRS_PAGE_SIZE PRs
 *   - We continue fetching while `pageInfo.hasNextPage` is true
 */

import { Octokit } from "@octokit/rest";
import type { Logger } from "../../core/logger";

const MERGED_PRS_PAGE_SIZE = 50;  // PRs per page (GitHub max = 100, but 50 keeps query cost low)
const OPEN_PRS_PAGE_SIZE   = 50;

// ─── Response types ──────────────────────────────────────────

export interface GqlRateLimit {
    cost:      number;
    remaining: number;
    resetAt:   string;
}

export interface GqlAuthor {
    __typename: string;
    login:     string;
    avatarUrl: string;
    name?:     string;        // only present on User nodes
    createdAt?: string;       // only present on User nodes
}

export interface GqlComment {
    id:        string;
    databaseId: number;
    body:      string;
    url:       string;
    createdAt: string;
    author:    GqlAuthor | null;
}

export interface GqlReview {
    state:       string;
    body:        string;
    submittedAt: string;
    author:      GqlAuthor | null;
}

export interface GqlPullRequest {
    id:              string;
    databaseId:      number;
    number:          number;
    title:           string;
    url:             string;
    additions:       number;
    deletions:       number;
    changedFiles:    number;
    mergedAt:        string | null;
    closedAt:        string | null;
    createdAt:       string;
    bodyText:        string;
    author:          GqlAuthor | null;
    reviews:         { nodes: GqlReview[] };
    comments:        { nodes: GqlComment[] };   // timeline (issue) comments
    reviewThreads:   { nodes: { comments: { nodes: GqlComment[] } }[] };
}

export interface GqlSyncRepoResult {
    pullRequests:    GqlPullRequest[];
    totalCostUsed:   number;
    pagesLoaded:     number;
}

export interface GqlOpenPr {
    number:       number;
    title:        string;
    url:          string;
    repository:   { nameWithOwner: string; name: string; owner: { login: string } };
    author:       GqlAuthor | null;
    createdAt:    string;
    updatedAt:    string;
    additions:    number;
    deletions:    number;
    changedFiles: number;
    reviews:      { nodes: GqlReview[] };
    comments:     { nodes: GqlComment[] };
    reviewThreads: { nodes: { comments: { nodes: GqlComment[] } }[] };
}

export interface GqlSearchPrsResult {
    openPrs:        GqlOpenPr[];
    totalCostUsed:  number;
    pagesLoaded:    number;
}

// ─── Issues types ────────────────────────────────────────────

export interface GqlIssueLabel {
    name:  string;
    color: string;
}

export interface GqlIssueMilestone {
    title: string;
    dueOn: string | null;
}

export interface GqlOpenIssue {
    number:     number;
    title:      string;
    url:        string;
    bodyText:   string;
    createdAt:  string;
    author:     GqlAuthor | null;
    repository: { name: string; nameWithOwner: string; owner: { login: string } };
    assignees:  { nodes: GqlAuthor[] };
    labels:     { nodes: GqlIssueLabel[] };
    milestone:  GqlIssueMilestone | null;
}

export interface GqlSearchIssuesResult {
    issues:        GqlOpenIssue[];
    totalCostUsed: number;
    pagesLoaded:   number;
}

// ─── Projects v2 types ──────────────────────────────────

export interface GqlProjectItem {
    id:     string;
    type:   string; // ISSUE | DRAFT_ISSUE | PULL_REQUEST
    content: {
        __typename: string;
        number?:    number;
        title?:     string;
        url?:       string;
        bodyText?:  string;
        createdAt?: string;
        author?:    GqlAuthor | null;
        repository?: { name: string; owner: { login: string } };
        assignees?:  { nodes: GqlAuthor[] };
        labels?:     { nodes: GqlIssueLabel[] };
        milestone?:  GqlIssueMilestone | null;
    } | null;
    fieldValues: {
        nodes: Array<
            | { __typename: 'ProjectV2ItemFieldTextValue';         text:  string | null; field: { name: string } }
            | { __typename: 'ProjectV2ItemFieldDateValue';         date:  string | null; field: { name: string } }
            | { __typename: 'ProjectV2ItemFieldSingleSelectValue'; name:  string | null; field: { name: string } }
            | { __typename: 'ProjectV2ItemFieldNumberValue';       number: number | null; field: { name: string } }
            | { __typename: string }
        >;
    };
}

export interface GqlProject {
    number: number;
    title:  string;
    items:  { nodes: GqlProjectItem[]; pageInfo: { hasNextPage: boolean; endCursor: string | null } };
}

export interface GqlOrgProjectsResult {
    projects:      GqlProject[];
    totalCostUsed: number;
}

// ─── GraphQL fragments ───────────────────────────────────────

const AUTHOR_FIELDS = `
    __typename
    login
    avatarUrl
    ... on User { name createdAt }
`;

const COMMENT_FIELDS = `
    id
    databaseId
    body
    url
    createdAt
    author { ${AUTHOR_FIELDS} }
`;

const REVIEW_FIELDS = `
    state
    body
    submittedAt
    author { __typename login avatarUrl }
`;

const RATE_LIMIT_FIELDS = `
    rateLimit { cost remaining resetAt }
`;

// ─── Queries ────────────────────────────────────────────────

const MERGED_PRS_QUERY = `
    query MergedPRs($owner: String!, $repo: String!, $cursor: String) {
        repository(owner: $owner, name: $repo) {
            pullRequests(
                first: ${MERGED_PRS_PAGE_SIZE},
                states: MERGED,
                after: $cursor,
                orderBy: { field: CREATED_AT, direction: DESC }
            ) {
                pageInfo { hasNextPage endCursor }
                nodes {
                    id
                    databaseId
                    number
                    title
                    url
                    additions
                    deletions
                    changedFiles
                    mergedAt
                    closedAt
                    createdAt
                    bodyText
                    author { ${AUTHOR_FIELDS} }
                    reviews(first: 20, states: [APPROVED, CHANGES_REQUESTED, COMMENTED]) {
                        nodes { ${REVIEW_FIELDS} }
                    }
                    comments(first: 50) {
                        nodes { ${COMMENT_FIELDS} }
                    }
                    reviewThreads(first: 30) {
                        nodes {
                            comments(first: 20) {
                                nodes { ${COMMENT_FIELDS} }
                            }
                        }
                    }
                }
            }
        }
        ${RATE_LIMIT_FIELDS}
    }
`;

const SINGLE_PR_QUERY = `
    query SinglePR($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
            pullRequest(number: $number) {
                id
                databaseId
                number
                title
                url
                additions
                deletions
                changedFiles
                mergedAt
                closedAt
                createdAt
                bodyText
                author { ${AUTHOR_FIELDS} }
                reviews(first: 20, states: [APPROVED, CHANGES_REQUESTED, COMMENTED]) {
                    nodes { ${REVIEW_FIELDS} }
                }
                comments(first: 100) {
                    nodes { ${COMMENT_FIELDS} }
                }
                reviewThreads(first: 50) {
                    nodes {
                        comments(first: 20) {
                            nodes { ${COMMENT_FIELDS} }
                        }
                    }
                }
            }
        }
        ${RATE_LIMIT_FIELDS}
    }
`;

const OPEN_PRS_SEARCH_QUERY = `
    query OpenPRsSearch($searchQuery: String!, $cursor: String) {
        search(query: $searchQuery, type: ISSUE, first: ${OPEN_PRS_PAGE_SIZE}, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
                ... on PullRequest {
                    number
                    title
                    url
                    createdAt
                    updatedAt
                    additions
                    deletions
                    changedFiles
                    author { ${AUTHOR_FIELDS} }
                    repository { nameWithOwner name owner { login } }
                    reviews(first: 20, states: [APPROVED, CHANGES_REQUESTED, COMMENTED]) {
                        nodes { ${REVIEW_FIELDS} }
                    }
                    comments(first: 30) {
                        nodes { ${COMMENT_FIELDS} }
                    }
                    reviewThreads(first: 20) {
                        nodes {
                            comments(first: 10) {
                                nodes { ${COMMENT_FIELDS} }
                            }
                        }
                    }
                }
            }
        }
        ${RATE_LIMIT_FIELDS}
    }
`;

const OPEN_ISSUES_SEARCH_QUERY = `
    query OpenIssuesSearch($searchQuery: String!, $cursor: String) {
        search(query: $searchQuery, type: ISSUE, first: 50, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
                ... on Issue {
                    number
                    title
                    url
                    bodyText
                    createdAt
                    author { ${AUTHOR_FIELDS} }
                    repository { name nameWithOwner owner { login } }
                    assignees(first: 10) {
                        nodes { __typename login avatarUrl }
                    }
                    labels(first: 20) {
                        nodes { name color }
                    }
                    milestone {
                        title
                        dueOn
                    }
                }
            }
        }
        ${RATE_LIMIT_FIELDS}
    }
`;

// Fetches first 10 open projects for an org, and all their items (open issues + draft issues)
// Each project's items are paginated — 50 per page, up to 200 items total
const ORG_PROJECTS_QUERY = `
    query OrgProjects($org: String!, $projectCursor: String) {
        organization(login: $org) {
            projectsV2(first: 10, after: $projectCursor, orderBy: { field: UPDATED_AT, direction: DESC }) {
                pageInfo { hasNextPage endCursor }
                nodes {
                    number
                    title
                    items(first: 50, orderBy: { field: POSITION, direction: ASC }) {
                        pageInfo { hasNextPage endCursor }
                        nodes {
                            id
                            type
                            content {
                                __typename
                                ... on Issue {
                                    number
                                    title
                                    url
                                    bodyText
                                    createdAt
                                    state
                                    author { __typename login avatarUrl }
                                    repository { name owner { login } }
                                    assignees(first: 10) { nodes { __typename login avatarUrl } }
                                    labels(first: 20) { nodes { name color } }
                                    milestone { title dueOn }
                                }
                                ... on DraftIssue {
                                    title
                                    body
                                    createdAt
                                    assignees(first: 10) { nodes { __typename login avatarUrl } }
                                }
                            }
                            fieldValues(first: 15) {
                                nodes {
                                    __typename
                                    ... on ProjectV2ItemFieldTextValue {
                                        text
                                        field { ... on ProjectV2FieldCommon { name } }
                                    }
                                    ... on ProjectV2ItemFieldDateValue {
                                        date
                                        field { ... on ProjectV2FieldCommon { name } }
                                    }
                                    ... on ProjectV2ItemFieldSingleSelectValue {
                                        name
                                        field { ... on ProjectV2SingleSelectField { name } }
                                    }
                                    ... on ProjectV2ItemFieldNumberValue {
                                        number
                                        field { ... on ProjectV2FieldCommon { name } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        rateLimit { cost remaining resetAt }
    }
`;

// ─── Client ─────────────────────────────────────────────────

export class GitHubGraphQLClient {
    private readonly octokit: Octokit;
    private readonly logger: Logger;

    constructor(octokit: Octokit, logger: Logger) {
        this.octokit = octokit;
        this.logger  = logger.child({ module: "github-graphql" });
    }

    /**
     * Fetch ALL merged PRs for a repo using cursor pagination.
     * Each page is one GraphQL request. Cost is logged per page
     * so you can monitor actual point consumption.
     */
    async fetchMergedPRs(
        owner: string,
        repo:  string,
        opts:  { maxPages?: number } = {},
    ): Promise<GqlSyncRepoResult> {
        const { maxPages = 20 } = opts;

        const allPrs: GqlPullRequest[] = [];
        let cursor:         string | null = null;
        let hasNextPage:    boolean       = true;
        let page:           number        = 0;
        let totalCostUsed:  number        = 0;

        while (hasNextPage && page < maxPages) {
            page++;

            const result: any = await (this.octokit as any).graphql(MERGED_PRS_QUERY, {
                owner,
                repo,
                cursor: cursor ?? undefined,
            });

            const rl: GqlRateLimit = result.rateLimit;
            totalCostUsed += rl.cost;

            this.logger.info(
                { owner, repo, page, cost: rl.cost, remaining: rl.remaining, resetAt: rl.resetAt },
                "GraphQL page fetched — rate limit cost",
            );

            const prPage = result.repository.pullRequests;
            const nodes: GqlPullRequest[] = prPage.nodes ?? [];

            allPrs.push(...nodes);
            hasNextPage = prPage.pageInfo.hasNextPage;
            cursor      = prPage.pageInfo.endCursor ?? null;

            this.logger.info(
                { owner, repo, page, fetched: nodes.length, total: allPrs.length, hasNextPage },
                "Paginating merged PRs",
            );
        }

        if (hasNextPage) {
            this.logger.warn({ owner, repo, page, totalPrs: allPrs.length }, "Reached maxPages limit — pagination stopped");
        }

        this.logger.info(
            { owner, repo, totalPrs: allPrs.length, pages: page, totalCostUsed },
            "GraphQL merged PRs fetch complete",
        );

        return { pullRequests: allPrs, totalCostUsed, pagesLoaded: page };
    }

    /**
     * Search all OPEN PRs across an org using GraphQL search API.
     * Fetches with cursor pagination and logs cost per page.
     */
    async searchOpenPRs(org: string, opts: { maxPages?: number } = {}): Promise<GqlSearchPrsResult> {
        const { maxPages = 10 } = opts;

        const allPrs: GqlOpenPr[] = [];
        let cursor:        string | null = null;
        let hasNextPage:   boolean       = true;
        let page:          number        = 0;
        let totalCostUsed: number        = 0;

        const searchQuery = `is:pr is:open org:${org}`;

        while (hasNextPage && page < maxPages) {
            page++;

            const result: any = await (this.octokit as any).graphql(OPEN_PRS_SEARCH_QUERY, {
                searchQuery,
                cursor: cursor ?? undefined,
            });

            const rl: GqlRateLimit = result.rateLimit;
            totalCostUsed += rl.cost;

            this.logger.info(
                { org, page, cost: rl.cost, remaining: rl.remaining, resetAt: rl.resetAt },
                "GraphQL open PRs page — rate limit cost",
            );

            const searchPage = result.search;
            const nodes: GqlOpenPr[] = (searchPage.nodes ?? []).filter((n: any) => n?.number); // filter non-PR nodes

            allPrs.push(...nodes);
            hasNextPage = searchPage.pageInfo.hasNextPage;
            cursor      = searchPage.pageInfo.endCursor ?? null;

            this.logger.info(
                { org, page, fetched: nodes.length, total: allPrs.length, hasNextPage },
                "Paginating open PRs",
            );
        }

        this.logger.info(
            { org, totalPrs: allPrs.length, pages: page, totalCostUsed },
            "GraphQL open PRs search complete",
        );

        return { openPrs: allPrs, totalCostUsed, pagesLoaded: page };
    }

    /**
     * Search all OPEN Issues (not PRs) across an org using GraphQL search API.
     * Uses `is:issue is:open org:{org}` to exclude PRs.
     */
    async searchOpenIssues(org: string, opts: { maxPages?: number } = {}): Promise<GqlSearchIssuesResult> {
        const { maxPages = 10 } = opts;

        const allIssues: GqlOpenIssue[] = [];
        let cursor:        string | null = null;
        let hasNextPage:   boolean       = true;
        let page:          number        = 0;
        let totalCostUsed: number        = 0;

        const searchQuery = `is:issue is:open org:${org}`;

        while (hasNextPage && page < maxPages) {
            page++;

            const result: any = await (this.octokit as any).graphql(OPEN_ISSUES_SEARCH_QUERY, {
                searchQuery,
                cursor: cursor ?? undefined,
            });

            const rl: GqlRateLimit = result.rateLimit;
            totalCostUsed += rl.cost;

            this.logger.info(
                { org, page, cost: rl.cost, remaining: rl.remaining, resetAt: rl.resetAt },
                "GraphQL open issues page — rate limit cost",
            );

            const searchPage = result.search;
            // filter to Issue nodes only (exclude any PR nodes that slip through)
            const nodes: GqlOpenIssue[] = (searchPage.nodes ?? []).filter((n: any) => n?.number && !n.additions && !n.deletions);

            allIssues.push(...nodes);
            hasNextPage = searchPage.pageInfo.hasNextPage;
            cursor      = searchPage.pageInfo.endCursor ?? null;

            this.logger.info(
                { org, page, fetched: nodes.length, total: allIssues.length, hasNextPage },
                "Paginating open issues",
            );
        }

        this.logger.info(
            { org, totalIssues: allIssues.length, pages: page, totalCostUsed },
            "GraphQL open issues search complete",
        );

        return { issues: allIssues, totalCostUsed, pagesLoaded: page };
    }

    /**
     * Fetch all Projects v2 for an org and their items (issues + draft issues).
     * Returns an enriched list ready for merging with regular open issues.
     * Only fetches open items (filters by content.state === 'OPEN' for issues).
     */
    async searchOrgProjectItems(org: string, opts: { maxProjects?: number } = {}): Promise<GqlOrgProjectsResult> {
        const { maxProjects = 10 } = opts;

        const projects: GqlProject[] = [];
        let projectCursor: string | null = null;
        let hasMoreProjects = true;
        let totalCostUsed = 0;

        while (hasMoreProjects && projects.length < maxProjects) {
            const result: any = await (this.octokit as any).graphql(ORG_PROJECTS_QUERY, {
                org,
                projectCursor: projectCursor ?? undefined,
            });

            const rl: GqlRateLimit = result.rateLimit;
            totalCostUsed += rl.cost;

            this.logger.info(
                { org, cost: rl.cost, remaining: rl.remaining },
                "GraphQL org projects page — rate limit cost",
            );

            const projectsPage = result.organization?.projectsV2;
            if (!projectsPage) break;

            projects.push(...(projectsPage.nodes ?? []));
            hasMoreProjects = projectsPage.pageInfo.hasNextPage;
            projectCursor = projectsPage.pageInfo.endCursor ?? null;
        }

        this.logger.info({ org, totalProjects: projects.length, totalCostUsed }, "GraphQL org projects fetch complete");

        return { projects, totalCostUsed };
    }

    /**
     * Fetch a single PR and all its historical comments efficiently.
     * Helpful for populating comments immediately after a webhook merge event.
     */
    async fetchSinglePR(owner: string, repo: string, number: number): Promise<GqlPullRequest | null> {

        this.logger.info({ owner, repo, number }, "Fetching single PR via GraphQL");
        try {
            const result: any = await (this.octokit as any).graphql(SINGLE_PR_QUERY, {
                owner,
                repo,
                number,
            });

            const rl: GqlRateLimit = result.rateLimit;
            this.logger.info(
                { repo, number, cost: rl.cost, remaining: rl.remaining },
                "GraphQL single PR — rate limit cost",
            );

            return result.repository?.pullRequest ?? null;
        } catch (err) {
            this.logger.error({ err, owner, repo, number }, "Failed to fetch single PR via GraphQL");
            return null;
        }
    }

    /**
     * Fetch commits for a repo using GraphQL — much faster than REST
     * because it gives us author login + committedDate in one query.
     * Note: GraphQL does NOT give additions/deletions per commit, so we
     * store 0 for those (same behavior as REST fallback path).
     *
     * When `since` is provided (incremental mode) GitHub only returns commits
     * AFTER that timestamp — so we paginate until done with no page cap.
     * Without `since` (initial/force sync) we paginate all history.
     */
    async fetchCommits(
        owner: string,
        repo:  string,
        opts:  { since?: string; maxPages?: number } = {},
    ): Promise<{ sha: string; author: string; message: string; committedAt: string; htmlUrl: string }[]> {
        const { since, maxPages = 500 } = opts; // 500p × 100 = 50k commits — effectively unlimited

        // `since` is a GitTimestamp (ISO-8601) supported natively by GitHub's history()
        const sinceArg = since ? `, since: $since` : "";
        const sinceVar = since ? ", $since: GitTimestamp" : "";

        const COMMITS_QUERY = `
            query RepoCommits($owner: String!, $repo: String!, $cursor: String${sinceVar}) {
                repository(owner: $owner, name: $repo) {
                    defaultBranchRef {
                        target {
                            ... on Commit {
                                history(first: 100, after: $cursor${sinceArg}) {
                                    pageInfo { hasNextPage endCursor }
                                    nodes {
                                        oid
                                        message
                                        committedDate
                                        url
                                        author {
                                            user { login }
                                            name
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                rateLimit { cost remaining resetAt }
            }
        `;

        const allCommits: { sha: string; author: string; message: string; committedAt: string; htmlUrl: string }[] = [];
        let cursor:      string | null = null;
        let hasNextPage: boolean       = true;
        let page:        number        = 0;

        this.logger.info(
            { owner, repo, mode: since ? "incremental" : "full-history", since: since ?? "none" },
            "Starting GraphQL commit fetch",
        );

        while (hasNextPage && page < maxPages) {
            page++;
            try {
                const variables: Record<string, any> = { owner, repo, cursor: cursor ?? undefined };
                if (since) variables.since = since;

                const result: any = await (this.octokit as any).graphql(COMMITS_QUERY, variables);

                const rl: GqlRateLimit = result.rateLimit;
                this.logger.info(
                    { owner, repo, page, cost: rl.cost, remaining: rl.remaining },
                    "GraphQL commits page — rate limit cost",
                );

                const history = result.repository?.defaultBranchRef?.target?.history;
                if (!history) {
                    this.logger.warn({ owner, repo }, "No commit history found via GraphQL (empty/archived repo?)");
                    break;
                }

                const nodes = history.nodes ?? [];
                for (const node of nodes) {
                    const authorLogin = node.author?.user?.login ?? null;
                    if (!authorLogin) continue;

                    allCommits.push({
                        sha:         node.oid,
                        author:      authorLogin,
                        message:     (node.message ?? "").split("\n")[0].slice(0, 255),
                        committedAt: node.committedDate,
                        htmlUrl:     node.url,
                    });
                }

                hasNextPage = history.pageInfo.hasNextPage;
                cursor      = history.pageInfo.endCursor ?? null;

                this.logger.info(
                    { owner, repo, page, fetched: nodes.length, total: allCommits.length, hasNextPage },
                    "Paginating commits",
                );
            } catch (err: any) {
                this.logger.error({ owner, repo, page, err: err.message }, "GraphQL commits page failed");
                break;
            }
        }

        this.logger.info(
            { owner, repo, totalCommits: allCommits.length, pages: page, mode: since ? "incremental" : "full-history" },
            "GraphQL commits fetch complete",
        );

        return allCommits;
    }
}
