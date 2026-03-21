/**
 * Sellio Metrics — GitHub Sync Service (GraphQL)
 *
 * Uses a single cursor-paginated GraphQL query per repo instead of
 * N×4 REST calls. Comments and author profiles come embedded in the
 * PR nodes — no secondary fetch loops needed.
 *
 * Request reduction (example: 50 merged PRs, 10 authors):
 *   Before:  ~65-70 REST calls  (~30s+ wall time)
 *   After:   1-2 GraphQL calls  (~2-4s wall time)
 *
 * Rate limit: GraphQL uses a POINT budget (5,000 pts/hour).
 * Each page costs ~5-15 pts. Actual cost is logged per-page
 * so you can monitor consumption in the Cloudflare dashboard.
 */

import type { Cradle } from "../../core/container";
import { isBot } from "../../lib/bot-filter";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";
import type { GqlPullRequest, GqlComment } from "../../infra/github/github-graphql.client";
import type { PrComment } from "../prs/comments.repository";

export async function syncOneRepo(
    cradle: Cradle,
    owner: string,
    repoName: string,
    orgRepos: any[],
    targetPrNumbers?: number[],
    force = false,   // if true, skip the since cutoff and re-sync all PRs
): Promise<object> {
    const {
        developerRepo, reposRepo, prsRepo, commentsRepo, logger,
        githubClient,
    } = cradle;

    const log = logger.child({ module: "sync", owner, repo: repoName });

    // Bust repo cache so fresh data is fetched
    await cradle.cacheService.del(`github:repos:${owner}`);

    // ─── Upsert repo with full metadata ─────────────────────
    const repoMeta = orgRepos.find((r: any) => r.name === repoName);
    if (!repoMeta?.id) throw new Error(`Repo metadata id missing for ${owner}/${repoName}`);

    const repoId = await reposRepo.upsertRepo(repoMeta.id as number, owner, repoName, {
        htmlUrl:         repoMeta?.html_url ?? `https://github.com/${owner}/${repoName}`,
        description:     repoMeta?.description ?? undefined,
        githubCreatedAt: repoMeta?.created_at ?? undefined,
        pushedAt:        repoMeta?.pushed_at ?? undefined,
    });

    // ─── Fetch merged PRs via GraphQL ───────────────────────
    const gql = new GitHubGraphQLClient(githubClient as any, logger);

    let allPrs: GqlPullRequest[];
    let totalCostUsed: number;
    let pagesLoaded: number;

    if (targetPrNumbers && targetPrNumbers.length > 0) {
        // Targeted sync: skip GraphQL, use existing data from DB + REST for just these PRs
        log.info({ prNumbers: targetPrNumbers }, "Targeted PR sync — using REST for specific PRs");
        return syncTargetedPrs(cradle, owner, repoName, repoId, targetPrNumbers, log);
    }

    // Determine since cutoff — skip if force=true
    let mostRecentMergedAt: string | undefined;
    if (!force) {
        const existingMergedPrs = await prsRepo.getMergedPrs({ repoId: repoMeta.id as number, limit: 5 });
        mostRecentMergedAt = existingMergedPrs.length > 0
            ? existingMergedPrs.reduce((latest: any, pr: any) =>
                (!latest || pr.mergedAt > latest.mergedAt) ? pr : latest,
            ).mergedAt
            : undefined;
    }

    // In incremental mode: only fetch the 3 newest pages (150 PRs) — enough for
    // any normal sprint between syncs. Force mode fetches all 20 pages.
    // The DB upsert is idempotent so re-syncing known PRs is safe.
    const maxPages = force ? 20 : (mostRecentMergedAt ? 3 : 20);

    log.info({ mode: force ? "force" : "incremental", maxPages }, "Starting GraphQL sync");

    const gqlResult = await gql.fetchMergedPRs(owner, repoName, { maxPages });
    allPrs        = gqlResult.pullRequests;
    totalCostUsed = gqlResult.totalCostUsed;
    pagesLoaded   = gqlResult.pagesLoaded;

    log.info({ prs: allPrs.length, pages: pagesLoaded, totalCostUsed }, "GraphQL fetch complete");

    // Filter out bots
    const mergedPrs = allPrs.filter(
        (pr) => !isBot(pr.author?.login ?? "", undefined),
    );

    // ─── Batch upsert developers (authors + commenters) ─────
    const authorsMap = new Map<string, { login: string; avatarUrl?: string; displayName?: string; joinedAt?: string }>();

    for (const pr of mergedPrs) {
        if (pr.author?.login) {
            authorsMap.set(pr.author.login, {
                login:       pr.author.login,
                avatarUrl:   pr.author.avatarUrl,
                displayName: pr.author.name,
                joinedAt:    pr.author.createdAt,
            });
        }
        // Comment authors
        for (const c of extractAllComments(pr)) {
            if (c.author?.login && !authorsMap.has(c.author.login)) {
                authorsMap.set(c.author.login, {
                    login:     c.author.login,
                    avatarUrl: c.author.avatarUrl,
                });
            }
        }
    }

    await developerRepo.upsertDeveloperBatch([...authorsMap.values()]);
    log.info({ developers: authorsMap.size }, "Batch upserted developers");

    // ─── Build and batch upsert PR rows ─────────────────────
    // Get existing PR numbers BEFORE upsert to know which are truly new
    const existingPrNums = await prsRepo.getExistingPrNumbers(repoId);

    const prRows = mergedPrs.map((pr) => ({
        id:          pr.databaseId,
        repoId,
        prNumber:    pr.number,
        author:      pr.author?.login ?? "ghost",
        title:       pr.title,
        body:        pr.bodyText,
        htmlUrl:     pr.url,
        mergedAt:    pr.mergedAt ?? pr.closedAt ?? new Date().toISOString(),
        prCreatedAt: pr.createdAt,
        additions:   pr.additions,
        deletions:   pr.deletions,
    }));

    const { inserted: prsInserted, updated: prsUpdated } = await prsRepo.upsertMergedPrBatch(prRows);
    log.info({ prsInserted, prsUpdated }, "PR upsert complete");

    // ─── Batch insert comments (only for NEW PRs) ────────────
    // Skip comment processing for PRs already in DB — they have their comments.
    // On force sync, existingPrNums is empty so all comments are processed.
    const newPrs = mergedPrs.filter((pr) => !existingPrNums.has(pr.number));
    const commentRows: PrComment[] = [];

    for (const pr of newPrs) {
        const prGithubId = pr.databaseId;

        for (const c of pr.comments.nodes) {
            const author = c.author?.login;
            if (!author || isBot(author, undefined)) continue;
            commentRows.push({
                id:          parseInt(c.databaseId.toString(), 10),
                prId:        prGithubId,
                repoId,
                prNumber:    pr.number,
                author,
                body:        c.body,
                commentType: "issue",
                htmlUrl:     c.url,
                commentedAt: c.createdAt,
            });
        }

        for (const thread of pr.reviewThreads.nodes) {
            for (const c of thread.comments.nodes) {
                const author = c.author?.login;
                if (!author || isBot(author, undefined)) continue;
                commentRows.push({
                    id:          parseInt(c.databaseId.toString(), 10),
                    prId:        prGithubId,
                    repoId,
                    prNumber:    pr.number,
                    author,
                    body:        c.body,
                    commentType: "review",
                    htmlUrl:     c.url,
                    commentedAt: c.createdAt,
                });
            }
        }
    }

    const commentsInserted = await commentsRepo.insertCommentBatch(commentRows);
    log.info({ newPrs: newPrs.length, comments: commentRows.length, inserted: commentsInserted }, "Batch inserted comments");

    // ─── Summary ─────────────────────────────────────────────
    // Line counts only for newly inserted PRs (not re-synced ones)
    let linesAdded = 0, linesDeleted = 0;
    for (const pr of newPrs) {
        linesAdded   += pr.additions ?? 0;
        linesDeleted += pr.deletions ?? 0;
    }

    return {
        ok:               true,
        repo:             `${owner}/${repoName}`,
        prsFound:         allPrs.length,
        mergedPrs:        mergedPrs.length,
        prsInserted,          // ← truly NEW PRs added this sync
        prsUpdated,           // ← already-known PRs that were re-synced (data refreshed)
        prsUpserted:      prsInserted,  // keep for backward compat with Flutter UI
        commentsInserted,
        linesAdded,
        linesDeleted,
        graphql: {
            pages:         pagesLoaded,
            totalCostUsed,
            method:        "graphql",
        },
    };
}

// ─── Targeted REST sync (for specific PR numbers only) ───────

async function syncTargetedPrs(
    cradle: Cradle,
    owner: string,
    repoName: string,
    repoId: number,
    targetPrNumbers: number[],
    log: any,
): Promise<object> {
    const { cachedGithubClient, prsRepo, developerRepo, commentsRepo } = cradle;

    // Fetch the specific PRs in parallel (max 10 at once)
    const batchSize = 10;
    const prRows: any[] = [];
    let restCalls = 0;

    for (let i = 0; i < targetPrNumbers.length; i += batchSize) {
        const chunk = targetPrNumbers.slice(i, i + batchSize);
        const details = await Promise.all(
            chunk.map((num) =>
                cachedGithubClient.getPull(owner, repoName, num, false).catch(() => null),
            ),
        );
        restCalls += chunk.length;

        for (const pr of details) {
            if (!pr || !pr.merged_at) continue;
            prRows.push({
                id:          pr.id,
                repoId,
                prNumber:    pr.number,
                author:      pr.user?.login ?? "ghost",
                title:       pr.title,
                htmlUrl:     pr.html_url,
                mergedAt:    pr.merged_at,
                prCreatedAt: pr.created_at,
                additions:   pr.additions ?? null,
                deletions:   pr.deletions ?? null,
            });
        }
    }

    const { inserted: upserted } = await prsRepo.upsertMergedPrBatch(prRows);

    const developers = prRows
        .filter((p) => p.author && p.author !== "ghost")
        .map((p) => ({ login: p.author }));
    await developerRepo.upsertDeveloperBatch(developers);

    log.info({ targetPrNumbers, upserted, restCalls }, "Targeted sync complete");

    return {
        ok: true,
        repo: `${owner}/${repoName}`,
        prsFound: targetPrNumbers.length,
        mergedPrs: prRows.length,
        prsUpserted: upserted,
        graphql: { method: "rest-targeted", restCalls },
    };
}

// ─── Helpers ─────────────────────────────────────────────────

function extractAllComments(pr: GqlPullRequest): GqlComment[] {
    const comments: GqlComment[] = [...pr.comments.nodes];
    for (const thread of pr.reviewThreads.nodes) {
        comments.push(...thread.comments.nodes);
    }
    return comments;
}

// ─── Org Members Sync (independent of PRs) ───────────────────

/**
 * Fetch all org members and enrich them with full GitHub profiles
 * (display_name, joined_at). Runs independently of PR sync.
 *
 * - Lists org members (slim: login + avatar_url)
 * - Fetches each profile via REST (cached 24h), 5 in parallel
 * - Batch upserts to developers table
 * - Filters out bots automatically
 */
export async function syncOrgMembers(
    cradle: Cradle,
    org:    string,
): Promise<{ synced: number; logins: string[] }> {
    const { cachedGithubClient, developerRepo, logger } = cradle;
    const log = logger.child({ module: "sync-members", org });

    // Bust members cache to get fresh list
    await cradle.cacheService.del(`github:org-members:${org}`);

    const members = await cachedGithubClient.listOrgMembers(org);
    log.info({ count: members.length }, "Org members fetched");

    // Filter bots
    const humanMembers = members.filter(
        (m: any) => !isBot(m.login ?? "", m.type),
    );

    // Fetch full profiles in parallel batches of 5
    const BATCH = 5;
    const enriched: Array<{ login: string; avatarUrl?: string; displayName?: string; joinedAt?: string }> = [];

    for (let i = 0; i < humanMembers.length; i += BATCH) {
        const chunk = humanMembers.slice(i, i + BATCH);
        const profiles = await Promise.all(
            chunk.map(async (m: any) => {
                try {
                    const profile = await cachedGithubClient.getUser(m.login);
                    return {
                        login:       m.login,
                        avatarUrl:   profile.avatar_url ?? m.avatar_url,
                        displayName: profile.name ?? undefined,
                        joinedAt:    profile.created_at ?? undefined,
                    };
                } catch {
                    return { login: m.login, avatarUrl: m.avatar_url };
                }
            }),
        );
        enriched.push(...profiles);
    }

    await developerRepo.upsertDeveloperBatch(enriched);
    log.info({ synced: enriched.length }, "Org members batch upserted with full profiles");

    return { synced: enriched.length, logins: enriched.map((e) => e.login) };
}
