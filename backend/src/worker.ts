/**
 * Sellio Metrics — Cloudflare Worker Entry Point
 *
 * Thin HTTP router + Cron handler.
 *
 * Architecture (Event-Driven Scoring):
 *   D1Service          — persistent event storage + SQL aggregation
 *   EventsService      — idempotent event ingestion
 *   PointsRulesService — dynamic point rules (KV + D1)
 *   ScoreAggregation   — leaderboard from events JOIN point_rules
 *   AttendanceService  — CHECK_IN / CHECK_OUT with duration scoring
 *   PrFetcherService   — fetches & enriches PRs from GitHub
 *   ResultCacheService — typed KV get/set for computed results
 *
 * Routes:
 *   GET  /api/ping
 *   GET  /api/health
 *   GET  /api/repos
 *   GET  /api/metrics/:owner/:repo/prs
 *   GET  /api/metrics/:owner/:repo/leaderboard
 *   GET  /api/metrics/:owner/:repo/members
 *   POST /api/webhooks/github      (event ingestion + cache invalidation)
 *   GET|PUT /api/points/rules
 *   GET  /api/scores/leaderboard
 *   GET  /api/events
 *   POST /api/attendance/check-in
 *   POST /api/attendance/check-out
 *   GET  /api/attendance/history
 *   GET|POST|DELETE /api/meetings/*
 *   GET|POST|DELETE /api/meet-events/*
 *   GET  /api/debug/auth
 *   GET  /api/debug/meet-subscribe
 *   GET  /api/debug/cache-quota
 */

import type { AwilixContainer } from "awilix";
import type { Cradle } from "./core/container";
import type { KVNamespace } from "./infra/cache/cache.service";
import type { D1Database } from "./infra/database/d1.service";
import { EventType, type ScoringEvent } from "./core/event-types";
import { ReposService } from "./modules/repos/repos.service";
import { PrFetcherService } from "./modules/metrics/pr-fetcher.service";
import { OpenPrsService } from "./modules/prs/open-prs.service";
import { EventsService } from "./modules/events/events.service";

// ─── Worker Env Bindings ────────────────────────────────────

interface WorkerEnv {
    APP_ID: string;
    INSTALLATION_ID: string;
    APP_PRIVATE_KEY: string;
    GITHUB_ORG?: string;
    LOG_LEVEL?: string;
    NODE_ENV?: string;
    GOOGLE_CLIENT_ID?: string;
    GOOGLE_CLIENT_SECRET?: string;
    GOOGLE_REDIRECT_URI?: string;
    GOOGLE_PUBSUB_TOPIC?: string;
    CACHE: KVNamespace;
    SCORES_KV: KVNamespace;
    MEMBERS_KV: KVNamespace;
    ATTENDANCE_KV: KVNamespace;
    DB: D1Database;
}

// ─── Console Logger ─────────────────────────────────────────

function createConsoleLogger(bindings: Record<string, unknown> = {}): any {
    const fmt = (msg: string, extra?: unknown) => {
        const parts = { ...bindings, ...(typeof extra === "object" && extra ? extra : {}) };
        return Object.keys(parts).length > 0 ? `[${JSON.stringify(parts)}] ${msg}` : msg;
    };
    const mk = (fn: (...args: any[]) => void) => (objOrMsg: unknown, msg?: string) =>
        typeof objOrMsg === "string" ? fn(objOrMsg) : fn(fmt(msg || "", objOrMsg as any));
    const logger: any = {
        info: mk(console.log), warn: mk(console.warn),
        error: mk(console.error), debug: mk(console.debug),
        fatal: (o: unknown, m?: string) => console.error(fmt(`[FATAL] ${m || ""}`, o)),
        trace: () => { /* no-op */ },
        child: (b: Record<string, unknown>) => createConsoleLogger({ ...bindings, ...b }),
        level: "info",
    };
    return logger;
}

// ─── Lazy Container Singleton ───────────────────────────────

let containerPromise: Promise<AwilixContainer<Cradle>> | null = null;

function getContainer(
    kvNamespace: KVNamespace | null,
    scoresKv: KVNamespace | null,
    membersKv: KVNamespace | null,
    attendanceKv: KVNamespace | null,
    d1Database: D1Database | null,
): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = (async () => {
            const { createContainer, asFunction, asClass, InjectionMode } = await import("awilix");
            const { env } = await import("./config/env");
            const { createGitHubClient } = await import("./infra/github/github.client");
            const { CacheService } = await import("./infra/cache/cache.service");
            const { D1Service } = await import("./infra/database/d1.service");
            const { RateLimitGuard } = await import("./infra/github/rate-limit-guard");
            const { CachedGitHubClient } = await import("./infra/github/cached-github.client");
            const { ReposService } = await import("./modules/repos/repos.service");
            const { PrFetcherService } = await import("./modules/metrics/pr-fetcher.service");
            const { GoogleMeetClient } = await import("./infra/google/google-meet.client");
            const { MeetingsService } = await import("./modules/meetings/meetings.service");
            const { WorkspaceEventsClient } = await import("./infra/google/workspace-events.client");
            const { MeetEventsService } = await import("./modules/meet-events/meet-events.service");
            const { LogsService } = await import("./modules/logs/logs.service");
            const { EventsService } = await import("./modules/events/events.service");
            const { PointsRulesService } = await import("./modules/points/points-rules.service");
            const { ScoreAggregationService } = await import("./modules/scores/score-aggregation.service");
            const { AttendanceService } = await import("./modules/attendance/attendance.service");

            const logger = createConsoleLogger();

            const container = createContainer<Cradle>({ injectionMode: InjectionMode.PROXY });

            container.register({
                env: asFunction(() => env).singleton(),
                logger: asFunction(() => logger).singleton(),

                githubClient: asFunction(({ env }: Cradle) =>
                    createGitHubClient({ env }),
                ).singleton(),

                kvNamespace: asFunction(() => kvNamespace).singleton(),

                cacheService: asFunction(({ kvNamespace, logger }: Cradle) =>
                    new CacheService({ kvNamespace, logger }),
                ).singleton(),

                // New namespace-specific cache services
                scoresKvCache: asFunction(({ logger }: Cradle) =>
                    new CacheService({ kvNamespace: scoresKv, logger }),
                ).singleton(),

                membersKvCache: asFunction(({ logger }: Cradle) =>
                    new CacheService({ kvNamespace: membersKv, logger }),
                ).singleton(),

                attendanceKvCache: asFunction(({ logger }: Cradle) =>
                    new CacheService({ kvNamespace: attendanceKv, logger }),
                ).singleton(),

                // D1 Database
                d1Service: asFunction(({ logger }: Cradle) =>
                    new D1Service({ d1Database, logger }),
                ).singleton(),

                rateLimitGuard: asFunction(({ logger, env }: Cradle) =>
                    new RateLimitGuard({ logger, githubRateLimitThreshold: env.githubRateLimitThreshold }),
                ).singleton(),

                cachedGithubClient: asFunction(({ githubClient, cacheService, membersKvCache, rateLimitGuard, logger }: Cradle) =>
                    new CachedGitHubClient({ githubClient, cacheService, membersKvCache, rateLimitGuard, logger }),
                ).singleton(),

                reposService: asClass(ReposService).singleton(),

                // Logs
                logsService: asClass(LogsService).singleton(),

                // Metrics: three focused services
                prFetcherService: asClass(PrFetcherService).singleton(),
                openPrsService: asClass(OpenPrsService).singleton(),

                // Event-Driven Scoring
                eventsService: asFunction(({ d1Service, scoresKvCache, logger }: Cradle) =>
                    new EventsService({ d1Service, scoresKvCache, logger }),
                ).singleton(),

                pointsRulesService: asFunction(({ d1Service, scoresKvCache, logger }: Cradle) =>
                    new PointsRulesService({ d1Service, scoresKvCache, logger }),
                ).singleton(),

                scoreAggregationService: asFunction(({ d1Service, scoresKvCache, logger }: Cradle) =>
                    new ScoreAggregationService({ d1Service, scoresKvCache, logger }),
                ).singleton(),

                attendanceService: asFunction(({ d1Service, attendanceKvCache, eventsService, logger }: Cradle) =>
                    new AttendanceService({ d1Service, attendanceKvCache, eventsService, logger }),
                ).singleton(),



                // Google Meet
                googleMeetClient: asFunction(({ logger, env, cacheService }: Cradle) =>
                    new GoogleMeetClient({
                        logger,
                        clientId: env.googleClientId,
                        clientSecret: env.googleClientSecret,
                        redirectUri: env.googleRedirectUri,
                        cacheService,
                    }),
                ).singleton(),
                meetingsService: asClass(MeetingsService).singleton(),
                workspaceEventsClient: asFunction(({ logger, cacheService }: Cradle) =>
                    new WorkspaceEventsClient({ logger, cacheService }),
                ).singleton(),
                meetEventsService: asFunction(({ logger, workspaceEventsClient, cacheService, env }: Cradle) =>
                    new MeetEventsService({
                        logger,
                        workspaceEventsClient,
                        cacheService,
                        pubsubTopic: env.googlePubsubTopic,
                    }),
                ).singleton(),
            });

            return container;
        })();
    }
    return containerPromise;
}

// ─── CORS ───────────────────────────────────────────────────

const CORS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
        status,
        headers: { "Content-Type": "application/json", ...CORS },
    });
}

function err(message: string, status = 500): Response {
    return json({ error: message }, status);
}

// ─── Handlers ───────────────────────────────────────────────

async function handleHealth(cradle: Cradle): Promise<Response> {
    return json({
        status: "ok",
        org: cradle.env.org,
        timestamp: new Date().toISOString(),
        githubRateLimit: cradle.rateLimitGuard.getStatus(),
        d1Available: cradle.d1Service.isAvailable,
    });
}

async function handleRepos(cradle: Cradle, url: URL): Promise<Response> {
    const org = url.searchParams.get("org") || cradle.env.org;
    const repos = await cradle.reposService.listByOrg(org);
    return json({ org, count: repos.length, repos });
}

async function handleOpenPrs(cradle: Cradle): Promise<Response> {
    const org = cradle.env.org;
    try {
        const prs = await cradle.openPrsService.fetchOpenPrs(org);
        return json({ data: prs });
    } catch (e: any) {
        cradle.logger.error({ err: e }, "Failed to fetch open PRs");
        return err(e.message, 500);
    }
}

// ─── GitHub Sync (Backfill) ───────────────────────────────

/**
 * Syncs a SINGLE repository into D1 using only 4-6 API calls total,
 * regardless of how many PRs or comments the repo has.
 *
 * Strategy (avoids the 1000 subrequest limit):
 *  1. getContributorStats()       → 1 call  → lines added/deleted per developer (matches GitHub UI)
 *  2. pulls.list (paginated)      → ~2 calls → PR_CREATED + PR_MERGED events
 *  3. listAllIssueComments()      → ~2 calls → all PR/issue comments in one pass
 *  4. listAllPRReviewComments()   → ~2 calls → all inline review comments in one pass
 */
async function handleGitHubSync(cradle: Cradle, request: Request): Promise<Response> {
    const { cachedGithubClient, eventsService, scoreAggregationService, env } = cradle;
    const body = await request.json().catch(() => ({})) as any;
    const owner = body.owner || env.org;
    const repoName: string | undefined = body.repo;

    if (!repoName) {
        return err(
            "Missing 'repo' in request body. Sync one repo at a time. Example: { \"repo\": \"sellio_mobile\" }",
            400,
        );
    }

    // Optionally clear old events for this repo first (set body.clear = true)
    if (body.clear === true) {
        await (cradle.d1Service as any).truncateAllEvents();
    }

    try {
        const events: ScoringEvent[] = [];
        const repoFull = `${owner}/${repoName}`;

        // ─── Fetch everything in parallel ────────────────────────────────────
        // Firing contributor stats FIRST (alongside other fetches) gives GitHub
        // ~15-30 extra seconds to compute while we paginate PRs and comments.
        // Sequential fetching gave GitHub only 3 seconds — not enough.
        const [contributorStats, prs, issueComments, reviewComments] = await Promise.all([
            cachedGithubClient.getContributorStats(owner, repoName),
            cachedGithubClient.listPulls(owner, repoName, "all", 100),
            cachedGithubClient.listAllIssueComments(owner, repoName),
            cachedGithubClient.listAllPRReviewComments(owner, repoName),
        ]);

        // ─── 1. Contributor stats → CODE_ADDITION + CODE_DELETION ───────────
        // Exact same data GitHub shows on /graphs/contributors.
        // Each contributor gets ONE aggregate event per repo (not per PR).
        if (contributorStats && Array.isArray(contributorStats)) {
            for (const contributor of contributorStats) {
                const login: string = contributor.author?.login;
                if (!login || login.endsWith("[bot]")) continue;

                // Sum additions and deletions across all weeks
                let totalAdditions = 0;
                let totalDeletions = 0;
                for (const week of contributor.weeks ?? []) {
                    totalAdditions += week.a ?? 0;
                    totalDeletions += week.d ?? 0;
                }

                if (totalAdditions > 0) {
                    events.push({
                        id: `github:code_additions:${repoFull}:${login}`,
                        developerId: login,
                        eventType: EventType.CODE_ADDITION,
                        source: "github",
                        sourceId: `https://github.com/${repoFull}/graphs/contributors`,
                        eventTimestamp: new Date().toISOString(),
                        metadata: { repo: repoFull, lines: totalAdditions },
                    });
                }
                if (totalDeletions > 0) {
                    events.push({
                        id: `github:code_deletions:${repoFull}:${login}`,
                        developerId: login,
                        eventType: EventType.CODE_DELETION,
                        source: "github",
                        sourceId: `https://github.com/${repoFull}/graphs/contributors`,
                        eventTimestamp: new Date().toISOString(),
                        metadata: { repo: repoFull, lines: totalDeletions },
                    });
                }
            }
        }

        for (const pr of prs) {
            const creator: string = pr.user?.login;
            if (!creator || creator.endsWith("[bot]")) continue;

            events.push({
                id: `github:pr_created:${repoFull}:${pr.number}:${creator}`,
                developerId: creator,
                eventType: EventType.PR_CREATED,
                source: "github",
                sourceId: pr.html_url,
                eventTimestamp: pr.created_at,
                metadata: { pr_number: pr.number, title: pr.title, repo: repoFull },
            });

            if (pr.merged_at) {
                events.push({
                    id: `github:pr_merged:${repoFull}:${pr.number}:${creator}`,
                    developerId: creator,
                    eventType: EventType.PR_MERGED,
                    source: "github",
                    sourceId: pr.html_url,
                    eventTimestamp: pr.merged_at,
                    metadata: { pr_number: pr.number, title: pr.title, repo: repoFull },
                });
            }
        }

        for (const comment of issueComments) {
            const author: string = comment.user?.login;
            if (!author || author.endsWith("[bot]")) continue;
            events.push({
                id: `github:comment:${repoName}:${comment.id}:${author}`,
                developerId: author,
                eventType: EventType.COMMENT,
                source: "github",
                sourceId: comment.html_url,
                eventTimestamp: comment.created_at,
                metadata: { repo: repoFull },
            });
        }

        for (const comment of reviewComments) {
            const author: string = comment.user?.login;
            if (!author || author.endsWith("[bot]")) continue;
            events.push({
                id: `github:review_comment:${repoName}:${comment.id}:${author}`,
                developerId: author,
                eventType: EventType.COMMENT,
                source: "github",
                sourceId: comment.html_url,
                eventTimestamp: comment.created_at,
                metadata: { repo: repoFull, pr_number: comment.pull_request_url?.split("/").pop() },
            });
        }

        // ─── Ingest ──────────────────────────────────────────────────────────
        let inserted = 0;
        let duplicates = 0;
        if (events.length > 0) {
            const result = await eventsService.ingestBatch(events);
            inserted = result.inserted;
            duplicates = result.duplicates;
        }

        // Precompute snapshots so leaderboard reflects new data immediately
        await scoreAggregationService.precomputeSnapshots();

        const statsOk = contributorStats != null && contributorStats.length > 0;
        return json({
            ok: true,
            repo: repoFull,
            prsFound: prs.length,
            mergedPrs: prs.filter((p: any) => !!p.merged_at).length,
            issueComments: issueComments.length,
            reviewComments: reviewComments.length,
            eventsGenerated: events.length,
            eventsInserted: inserted,
            duplicates,
            lineStatsSource: statsOk
                ? `GitHub contributor stats (${contributorStats!.length} contributors)`
                : "GitHub stats unavailable — re-sync this repo in a few minutes",
        });

    } catch (e: any) {
        return err(`Sync failed: ${e.message}`, 500);
    }
}

// ─── Clear All Events Handler ────────────────────────────

async function handleClearEvents(cradle: Cradle): Promise<Response> {
    const deleted = await (cradle.d1Service as any).truncateAllEvents();
    await cradle.scoreAggregationService.precomputeSnapshots();
    return json({ ok: true, eventsDeleted: deleted });
}



// ─── Webhook Handler (Event-Driven) ─────────────────────────

async function handleWebhook(cradle: Cradle, request: Request): Promise<Response> {
    const event = request.headers.get("x-github-event");
    const RELEVANT = new Set(["pull_request", "pull_request_review", "issue_comment", "pull_request_review_comment", "organization", "member", "membership"]);

    if (!event || !RELEVANT.has(event)) return json({ ignored: true, event });

    const payload = await request.json() as any;

    if (["organization", "member", "membership"].includes(event)) {
        const org = payload.organization?.login || cradle.env.org;
        await cradle.membersKvCache.del(`github:org-members:${org}`);
        cradle.logger.info({ org, event }, "Invalidated org-members cache due to webhook");
        return json({ ok: true, event, cache_invalidated: true });
    }

    const repo = payload?.repository;
    if (!repo?.full_name) return json({ ignored: true, reason: "no repo" });

    // Invalidate open PRs cache immediately (it's completely dynamic)
    const org = repo.owner?.login || repo.full_name.split("/")[0] || cradle.env.org;
    cradle.openPrsService.invalidateCache(org).catch((e: any) => 
        cradle.logger.error({ err: e.message, org }, "Failed to invalidate open-prs cache in webhook")
    );

    // Ingest events into D1 (event-driven scoring)
    const events: ScoringEvent[] = [];
    const action = payload?.action;

    if (event === "pull_request" && payload.pull_request) {
        const pr = payload.pull_request;
        const creator = pr.user?.login;
        if (!creator) return json({ ok: true, event, reason: "no user" });

        if (action === "opened" || action === "reopened") {
            events.push({
                id: `github:pr_created:${repo.full_name}:${pr.number}:${creator}`,
                developerId: creator,
                eventType: EventType.PR_CREATED,
                source: "github",
                sourceId: pr.html_url,
                eventTimestamp: pr.created_at,
                metadata: { pr_number: pr.number, title: pr.title, repo: repo.full_name },
            });
        }

        if (action === "closed" && pr.merged) {
            const mergeTs = pr.merged_at || pr.closed_at || new Date().toISOString();
            events.push({
                id: `github:pr_merged:${repo.full_name}:${pr.number}:${creator}`,
                developerId: creator,
                eventType: EventType.PR_MERGED,
                source: "github",
                sourceId: pr.html_url,
                eventTimestamp: mergeTs,
                metadata: { pr_number: pr.number, title: pr.title, repo: repo.full_name },
            });
            // Capture final line counts at merge time
            if (typeof pr.additions === "number" && pr.additions > 0) {
                events.push({
                    id: `github:code_additions:${repo.full_name}:${pr.number}:${creator}`,
                    developerId: creator,
                    eventType: EventType.CODE_ADDITION,
                    source: "github",
                    sourceId: pr.html_url,
                    eventTimestamp: mergeTs,
                    metadata: { pr_number: pr.number, repo: repo.full_name, lines: pr.additions },
                });
            }
            if (typeof pr.deletions === "number" && pr.deletions > 0) {
                events.push({
                    id: `github:code_deletions:${repo.full_name}:${pr.number}:${creator}`,
                    developerId: creator,
                    eventType: EventType.CODE_DELETION,
                    source: "github",
                    sourceId: pr.html_url,
                    eventTimestamp: mergeTs,
                    metadata: { pr_number: pr.number, repo: repo.full_name, lines: pr.deletions },
                });
            }
        }
    }

    // pull_request_review events have been explicitly requested to be removed.

    if ((event === "issue_comment" || event === "pull_request_review_comment") && payload.comment) {
        const comment = payload.comment;
        const author = comment.user?.login;
        // Skip bots entirely — they should not earn points or appear on the leaderboard
        if (author && action === "created" && !author.endsWith("[bot]")) {
            const prNumber = payload.issue?.number || payload.pull_request?.number;
            events.push({
                id: `github:comment:${repo.full_name}:${comment.id}:${author}`,
                developerId: author,
                eventType: EventType.COMMENT,
                source: "github",
                sourceId: comment.html_url,
                eventTimestamp: comment.created_at,
                metadata: { pr_number: prNumber, repo: repo.full_name },
            });
        }
    }

    // Ingest all events
    let ingested = 0;
    let duplicates = 0;
    if (events.length > 0) {
        const result = await cradle.eventsService.ingestBatch(events);
        ingested = result.inserted;
        duplicates = result.duplicates;

        // Refresh the leaderboard snapshot in the background so scores update
        // immediately without blocking the webhook response (fire-and-forget).
        if (ingested > 0) {
            cradle.scoreAggregationService.precomputeSnapshots().catch((e: any) =>
                cradle.logger.warn({ err: e.message }, "Failed to refresh leaderboard after webhook")
            );
        }
    }

    return json({ ok: true, event, repo: repo.full_name, eventsIngested: ingested, duplicates });
}

// ─── Points Rules Handlers ──────────────────────────────────

async function handleGetPointsRules(cradle: Cradle): Promise<Response> {
    const rules = await cradle.pointsRulesService.getRules();
    return json({ rules });
}

async function handleUpdatePointRule(cradle: Cradle, request: Request): Promise<Response> {
    const body = await request.json() as any;
    const { eventType, points, description } = body;

    if (!eventType || typeof points !== "number") {
        return err("Body must contain 'eventType' (string) and 'points' (number)", 400);
    }

    const rule = await cradle.pointsRulesService.updateRule(eventType, points, description);
    return json({ ok: true, rule });
}

// ─── Scores Leaderboard Handler ─────────────────────────────

async function handleScoresLeaderboard(cradle: Cradle, url: URL): Promise<Response> {
    const since = url.searchParams.get("since") || undefined;
    const until = url.searchParams.get("until") || undefined;
    const limit = parseInt(url.searchParams.get("limit") || "50", 10);

    const result = await cradle.scoreAggregationService.getLeaderboard(since, until, limit);

    try {
        const orgMembers = await cradle.cachedGithubClient.listOrgMembers(cradle.env.org);
        const avatarMap = new Map(orgMembers.map((m: any) => [m.login, m.avatar_url]));
        // Only include members that belong to the org's GitHub member list
        const memberLogins = new Set(orgMembers.map((m: any) => m.login as string));

        result.entries = result.entries
            // Exclude non-members AND bot accounts (suffix: [bot])
            .filter((entry: any) => memberLogins.has(entry.developer_id) && !entry.developer_id.endsWith("[bot]"))
            .map((entry: any) => ({
                ...entry,
                avatarUrl: avatarMap.get(entry.developer_id) || `https://github.com/${entry.developer_id}.png`
            }));
    } catch (e: any) {
        cradle.logger.warn({ err: e.message }, "Failed to fetch avatarUrls for leaderboard");
    }

    return json(result);
}

// ─── Delete Developer Events Handler ─────────────────────────

async function handleDeleteDeveloper(cradle: Cradle, developerId: string): Promise<Response> {
    if (!developerId) return err("Missing developerId", 400);
    const deleted = await cradle.d1Service.deleteEventsByDeveloper(developerId);
    // Invalidate leaderboard cache so the change is reflected immediately
    try {
        await (cradle as any).scoresKvCache?.del("leaderboard:all:all");
    } catch { /* ignore */ }
    await cradle.scoreAggregationService.precomputeSnapshots();
    return json({ ok: true, developerId, eventsDeleted: deleted });
}

// ─── Members Handler ────────────────────────────────────────

async function handleMembers(cradle: Cradle): Promise<Response> {
    try {
        const orgMembers = await cradle.cachedGithubClient.listOrgMembers(cradle.env.org);
        // 30 day window for strictly active vs inactive flag
        const sinceDate = new Date();
        sinceDate.setDate(sinceDate.getDate() - 30);
        const thirtyDaysAgo = sinceDate.getTime();

        // Get absolute last active dates directly from D1 using optimized query
        const activityMap = await cradle.eventsService.getLastActiveDates();

        const mappedMembers = orgMembers.map((m: any) => {
            // Be case-insensitive during lookups just in case
            const developerIdMatch = Object.keys(activityMap).find((k) => k.toLowerCase() === m.login.toLowerCase());
            const lastActive = developerIdMatch ? activityMap[developerIdMatch] : null;
            const isActive = !!lastActive && new Date(lastActive).getTime() >= thirtyDaysAgo;
            
            return {
                developer: m.login,
                avatarUrl: m.avatar_url,
                isActive,
                lastActiveDate: lastActive
            };
        });

        // Sort: Active first, then by last active date desc, then by name
        mappedMembers.sort((a: any, b: any) => {
            if (a.isActive && !b.isActive) return -1;
            if (!a.isActive && b.isActive) return 1;
            if (a.isActive && b.isActive) {
                return new Date(b.lastActiveDate!).getTime() - new Date(a.lastActiveDate!).getTime();
            }
            return a.developer.localeCompare(b.developer);
        });

        return json({ data: mappedMembers, members: mappedMembers });
    } catch (e: any) {
        cradle.logger.error({ err: e.message }, "Failed to fetch members status");
        return err("Failed to fetch developers.", 500);
    }
}

// ─── Events Handler ─────────────────────────────────────────

async function handleListEvents(cradle: Cradle, url: URL): Promise<Response> {
    const developerId = url.searchParams.get("developerId") || undefined;
    const eventType = url.searchParams.get("eventType") || undefined;
    const since = url.searchParams.get("since") || undefined;
    const until = url.searchParams.get("until") || undefined;
    const limit = parseInt(url.searchParams.get("limit") || "50", 10);

    const events = await cradle.eventsService.listEvents({ developerId, eventType, since, until, limit });
    return json({ count: events.length, events });
}

// ─── Attendance Handlers ────────────────────────────────────

async function handleCheckIn(cradle: Cradle, request: Request): Promise<Response> {
    const body = await request.json() as any;
    const { developerId, checkin_time, meeting_id, location } = body;

    if (!developerId) return err("Body must contain 'developerId'", 400);

    try {
        const result = await cradle.attendanceService.checkIn(developerId, {
            checkin_time: checkin_time || new Date().toISOString(),
            meeting_id,
            location,
        });
        return json(result);
    } catch (e: any) {
        return err(e.message, 400);
    }
}

async function handleCheckOut(cradle: Cradle, request: Request): Promise<Response> {
    const body = await request.json() as any;
    const { developerId, checkout_time, meeting_id, location } = body;

    if (!developerId) return err("Body must contain 'developerId'", 400);

    try {
        const result = await cradle.attendanceService.checkOut(developerId, {
            checkout_time: checkout_time || new Date().toISOString(),
            meeting_id,
            location,
        });
        return json(result);
    } catch (e: any) {
        return err(e.message, 400);
    }
}

async function handleAttendanceHistory(cradle: Cradle, url: URL): Promise<Response> {
    const developerId = url.searchParams.get("developerId") || undefined;
    const since = url.searchParams.get("since") || undefined;
    const until = url.searchParams.get("until") || undefined;
    const limit = parseInt(url.searchParams.get("limit") || "50", 10);

    const events = await cradle.attendanceService.getHistory({ developerId, since, until, limit });
    return json({ count: events.length, events });
}

// ─── Debug Handlers ─────────────────────────────────────────

async function handleDebugAuth(cradle: Cradle): Promise<Response> {
    const { googleClientId: clientId, googleClientSecret: clientSecret, googleRedirectUri: redirectUri, googlePubsubTopic } = cradle.env;
    const kvToken = await cradle.cacheService.get<any>("google_oauth_tokens");
    const isReady = await cradle.meetingsService.isReady();

    return json({
        hasClientId: !!clientId && clientId.length > 10,
        hasClientSecret: !!clientSecret && clientSecret.length > 10,
        clientIdPrefix: clientId ? clientId.substring(0, 20) + "…" : "MISSING",
        redirectUri,
        kvIsBound: !!cradle.kvNamespace,
        kvHasToken: !!kvToken,
        tokenHasAccessToken: !!(kvToken?.data?.access_token),
        tokenHasRefreshToken: !!(kvToken?.data?.refresh_token),
        tokenCachedAt: kvToken?.cachedAt ?? null,
        tokenExpiryDate: kvToken?.data?.expiry_date ?? null,
        isReady,
        pubsubTopic: googlePubsubTopic || "NOT_SET",
    });
}

async function handleDebugMeetSubscribe(cradle: Cradle, url: URL): Promise<Response> {
    const kvToken = await cradle.cacheService.get<any>("google_oauth_tokens");
    const isReady = await cradle.meetingsService.isReady();
    const spaceName = url.searchParams.get("spaceName") || "spaces/ONkdRwFFaFMB";
    let subscribeResult: any = null;
    let subscribeError: string | null = null;

    if (isReady && cradle.env.googlePubsubTopic) {
        try {
            subscribeResult = await cradle.meetEventsService.subscribe(spaceName);
        } catch (e: any) {
            subscribeError = e?.message || String(e);
        }
    } else {
        subscribeError = !isReady
            ? "NOT_READY: OAuth token missing from KV. Please re-authenticate."
            : "No GOOGLE_PUBSUB_TOPIC configured.";
    }

    return json({
        tokenInfo: {
            exists: !!kvToken,
            hasAccessToken: !!(kvToken?.data?.access_token),
            hasRefreshToken: !!(kvToken?.data?.refresh_token),
            accessTokenPrefix: kvToken?.data?.access_token ? kvToken.data.access_token.substring(0, 20) + "…" : null,
            expiry_date: kvToken?.data?.expiry_date ?? null,
            cachedAt: kvToken?.cachedAt ?? null,
        },
        isReady,
        pubsubTopic: cradle.env.googlePubsubTopic || "NOT_SET",
        spaceName,
        subscribeResult,
        subscribeError,
    });
}

async function handleDebugCacheQuota(cradle: Cradle): Promise<Response> {
    const now = new Date();
    const midnight = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
    const secondsToReset = Math.floor((midnight.getTime() - now.getTime()) / 1000);

    const defaultRepo = `${cradle.env.org}/sellio_mobile`;
    const [owner, repoName] = defaultRepo.split("/");
    const [repos, orgMembers, token] = await Promise.all([
        cradle.cacheService.get<any>(`github:repos:${cradle.env.org}`),
        cradle.membersKvCache.get<any>(`github:org-members:${cradle.env.org}`),
        cradle.cacheService.get<any>("google_oauth_tokens"),
    ]);

    return json({
        kvFreeWriteLimit: 1000,
        kvResetAtUtc: midnight.toISOString(),
        kvSecondsToReset: secondsToReset,
        kvResetNote: "Cloudflare KV free tier resets daily at midnight UTC",
        maxWritesPerRequest: 3,
        strategy: "Only computed results are cached (leaderboard + members + metrics). No per-PR writes.",
        d1Available: cradle.d1Service.isAvailable,
        cachedResults: {
            "SCORES_KV": "Now managed automatically",
            [`github:repos:${cradle.env.org}`]: { hit: !!repos },
            [`github:org-members:${cradle.env.org}`]: { hit: !!orgMembers },
            "google_oauth_tokens": { hit: !!token },
        },
    });
}

// ─── Meetings Handler ────────────────────────────────────────

async function handleMeetings(cradle: Cradle, request: Request, path: string, url: URL): Promise<Response> {
    const { meetingsService } = cradle;

    if (request.method === "GET") {
        if (path === "/auth-url") return json({ authUrl: meetingsService.getAuthUrl() });
        if (path === "/auth-status") return json({ isReady: await meetingsService.isReady() });
        if (path === "/oauth2callback") {
            const code = url.searchParams.get("code");
            const error = url.searchParams.get("error");
            if (error) {
                return new Response(
                    `<html><body style="font-family:sans-serif;padding:24px">
                    <h2 style="color:red">❌ Authentication Failed</h2>
                    <p><b>Error:</b> ${error}</p>
                    <p>Check that this Google account is added as a test user in
                    <a href="https://console.cloud.google.com/apis/credentials/consent" target="_blank">
                    Google Cloud Console → OAuth consent screen</a>.</p>
                    </body></html>`,
                    { headers: { "Content-Type": "text/html", ...CORS } },
                );
            }
            if (!code) return err("Missing code", 400);
            try {
                await meetingsService.authorize(code);
                return new Response(
                    `<html><body style="font-family:sans-serif;padding:24px">
                    <h2 style="color:green">✅ Signed in successfully!</h2>
                    <p>This window will close in 3 seconds…</p>
                    <script>setTimeout(() => window.close(), 3000);</script>
                    </body></html>`,
                    { headers: { "Content-Type": "text/html", ...CORS } },
                );
            } catch (e: any) {
                return new Response(
                    `<html><body style="font-family:sans-serif;padding:24px">
                    <h2 style="color:red">❌ Token Exchange Failed</h2>
                    <p><b>Error:</b> ${e?.message || "Unknown error"}</p>
                    <p>Possible causes: invalid OAuth credentials, redirect URI mismatch, or KV write quota exceeded.</p>
                    </body></html>`,
                    { status: 500, headers: { "Content-Type": "text/html", ...CORS } },
                );
            }
        }
        if (path === "/rate-limit") return json(meetingsService.getRateLimitStatus());
        if (path === "/analytics") return json(await meetingsService.getAnalytics());
        if (path === "" || path === "/") return json(await meetingsService.listMeetings());

        const idMatch = path.match(/^\/([^/]+)$/);
        if (idMatch) return json(await meetingsService.getMeeting(idMatch[1]));
        const attMatch = path.match(/^\/([^/]+)\/attendance$/);
        if (attMatch) return json(await meetingsService.getAttendance(attMatch[1]));
    }

    if (request.method === "POST") {
        if (path === "/auth-logout") {
            await meetingsService.clearCredentials();
            return json({ success: true });
        }
        if (path === "" || path === "/") {
            if (!(await meetingsService.isReady())) {
                return json({ error: "UNAUTHORIZED", message: "Sign in required.", authUrl: meetingsService.getAuthUrl() }, 401);
            }
            const body = await request.json() as any;
            return json(await meetingsService.createMeeting(body.title));
        }
        const endMatch = path.match(/^\/([^/]+)\/end$/);
        if (endMatch) {
            await meetingsService.endMeeting(endMatch[1]);
            return json({ success: true });
        }
    }

    return err("Not Found", 404);
}

// ─── Meet Events Handler ─────────────────────────────────────

async function handleMeetEvents(cradle: Cradle, request: Request, path: string, url: URL): Promise<Response> {
    try {
        const { meetEventsService, meetingsService } = cradle;

        if (request.method === "POST" && path === "/webhook") {
            const body = await request.json() as any;
            const event = await meetEventsService.handleWebhook(body);
            return json({ ok: true, eventId: event.id, type: event.label });
        }

        if (request.method === "POST" && path === "/subscribe") {
            if (!(await meetingsService.isReady())) {
                return json({ error: "UNAUTHORIZED", message: "Google OAuth sign-in required.", authUrl: meetingsService.getAuthUrl() }, 401);
            }
            const body = await request.json() as any;
            const spaceName = body?.spaceName;
            if (!spaceName) return err("Body must contain 'spaceName'", 400);
            return json(await meetEventsService.subscribe(spaceName));
        }

        if (request.method === "GET" && path === "/events") {
            const limit = parseInt(url.searchParams.get("limit") || "50", 10);
            const events = await meetEventsService.listEvents(limit);
            return json({ count: events.length, events });
        }

        if (request.method === "GET" && path === "/subscriptions") {
            const subscriptions = await meetEventsService.listSubscriptions();
            return json({ count: subscriptions.length, subscriptions });
        }

        if (request.method === "DELETE" && path.startsWith("/subscriptions/")) {
            await meetEventsService.deleteSubscription(path.replace("/subscriptions/", ""));
            return json({ ok: true });
        }

        return err("Not Found", 404);
    } catch (e: any) {
        console.error("Meet events error:", e?.message, e?.stack);
        return err(e?.message || "Internal Server Error");
    }
}

// ─── Router ─────────────────────────────────────────────────

function matchRoute(p: string): { handler: string; params?: Record<string, string> } | null {
    if (p === "/api/ping") return { handler: "ping" };
    if (p === "/api/health") return { handler: "health" };
    if (p === "/api/repos") return { handler: "repos" };
    if (p === "/api/prs") return { handler: "openPrs" };
    if (p === "/api/webhooks/github") return { handler: "webhook" };
    if (p === "/api/debug/auth") return { handler: "debugAuth" };
    if (p === "/api/debug/meet-subscribe") return { handler: "debugMeetSubscribe" };
    if (p === "/api/debug/cache-quota") return { handler: "debugCacheQuota" };
    if (p === "/api/logs") return { handler: "logs" };

    // New event-driven routes
    if (p === "/api/points/rules") return { handler: "pointsRules" };
    if (p === "/api/scores/leaderboard") return { handler: "scoresLeaderboard" };
    if (p === "/api/members") return { handler: "members" };
    if (p === "/api/events") return { handler: "events" };
    if (p === "/api/events/clear") return { handler: "clearEvents" };
    if (p === "/api/attendance/check-in") return { handler: "checkIn" };
    if (p === "/api/attendance/check-out") return { handler: "checkOut" };
    if (p === "/api/attendance/history") return { handler: "attendanceHistory" };
    if (p === "/api/sync/github") return { handler: "syncGithub" };

    const devDeleteMatch = p.match(/^\/api\/developers\/([^/]+)\/events$/);
    if (devDeleteMatch) return { handler: "deleteDeveloper", params: { developerId: devDeleteMatch[1] } };

    if (p.startsWith("/api/meetings")) return { handler: "meetings", params: { path: p.replace("/api/meetings", "") } };
    if (p.startsWith("/api/meet-events")) return { handler: "meetEvents", params: { path: p.replace("/api/meet-events", "") } };

    return null;
}

// ─── Fetch Handler ──────────────────────────────────────────

export default {
    async fetch(request: Request, workerEnv: WorkerEnv): Promise<Response> {
        if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });

        const url = new URL(request.url);
        if (url.pathname === "/api/ping") {
            return new Response(JSON.stringify({ pong: true, time: new Date().toISOString() }), {
                headers: { "Content-Type": "application/json", ...CORS },
            });
        }

        try {
            if (!process.env.APP_ID) {
                process.env.APP_ID = workerEnv.APP_ID;
                process.env.INSTALLATION_ID = workerEnv.INSTALLATION_ID;
                process.env.APP_PRIVATE_KEY = workerEnv.APP_PRIVATE_KEY;
                if (workerEnv.GITHUB_ORG) process.env.GITHUB_ORG = workerEnv.GITHUB_ORG;
                if (workerEnv.LOG_LEVEL) process.env.LOG_LEVEL = workerEnv.LOG_LEVEL;
                if (workerEnv.GOOGLE_CLIENT_ID) process.env.GOOGLE_CLIENT_ID = workerEnv.GOOGLE_CLIENT_ID;
                if (workerEnv.GOOGLE_CLIENT_SECRET) process.env.GOOGLE_CLIENT_SECRET = workerEnv.GOOGLE_CLIENT_SECRET;
                if (workerEnv.GOOGLE_REDIRECT_URI) process.env.GOOGLE_REDIRECT_URI = workerEnv.GOOGLE_REDIRECT_URI;
                if (workerEnv.GOOGLE_PUBSUB_TOPIC) process.env.GOOGLE_PUBSUB_TOPIC = workerEnv.GOOGLE_PUBSUB_TOPIC;
            }

            const container = await getContainer(
                workerEnv.CACHE || null,
                workerEnv.SCORES_KV || null,
                workerEnv.MEMBERS_KV || null,
                workerEnv.ATTENDANCE_KV || null,
                workerEnv.DB || null,
            );
            const cradle = container.cradle;
            const route = matchRoute(url.pathname);

            if (!route) return err("Not Found", 404);

            switch (route.handler) {
                case "health": return handleHealth(cradle);
                case "repos": return handleRepos(cradle, url);
                case "openPrs": return handleOpenPrs(cradle);
                case "syncGithub":
                    if (request.method !== "POST") return err("Method Not Allowed", 405);
                    return handleGitHubSync(cradle, request);
                case "webhook":
                    if (request.method !== "POST") return err("Method Not Allowed", 405);
                    return handleWebhook(cradle, request);
                case "pointsRules":
                    if (request.method === "GET") return handleGetPointsRules(cradle);
                    if (request.method === "PUT") return handleUpdatePointRule(cradle, request);
                    return err("Method Not Allowed", 405);
                case "scoresLeaderboard":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleScoresLeaderboard(cradle, url);
                case "members":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleMembers(cradle);
                case "events":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleListEvents(cradle, url);
                case "clearEvents":
                    if (request.method !== "DELETE") return err("Method Not Allowed", 405);
                    return handleClearEvents(cradle);
                case "checkIn":
                    if (request.method !== "POST") return err("Method Not Allowed", 405);
                    return handleCheckIn(cradle, request);
                case "checkOut":
                    if (request.method !== "POST") return err("Method Not Allowed", 405);
                    return handleCheckOut(cradle, request);
                case "attendanceHistory":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleAttendanceHistory(cradle, url);
                case "deleteDeveloper":
                    if (request.method !== "DELETE") return err("Method Not Allowed", 405);
                    return handleDeleteDeveloper(cradle, route.params!.developerId);
                case "meetings": return handleMeetings(cradle, request, route.params!.path, url);
                case "meetEvents": return handleMeetEvents(cradle, request, route.params!.path, url);
                case "logs":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    const limit = parseInt(url.searchParams.get("limit") || "50", 10);
                    return json(await cradle.logsService.getLogs(limit));
                case "debugAuth": return handleDebugAuth(cradle);
                case "debugMeetSubscribe": return handleDebugMeetSubscribe(cradle, url);
                case "debugCacheQuota": return handleDebugCacheQuota(cradle);
                default: return err("Not Found", 404);
            }
        } catch (e: any) {
            console.error("Worker error:", e?.message || e, e?.stack);
            return new Response(JSON.stringify({ error: e?.message || "Internal Server Error" }), {
                status: 500,
                headers: { "Content-Type": "application/json", ...CORS },
            });
        }
    },

    // ─── Cron Trigger (Scheduled) ───────────────────────────

    async scheduled(event: ScheduledEvent, workerEnv: WorkerEnv, ctx: ExecutionContext): Promise<void> {
        console.log("Cron trigger fired:", new Date().toISOString());

        try {
            if (!process.env.APP_ID && workerEnv.APP_ID) {
                process.env.APP_ID = workerEnv.APP_ID;
                process.env.INSTALLATION_ID = workerEnv.INSTALLATION_ID;
                process.env.APP_PRIVATE_KEY = workerEnv.APP_PRIVATE_KEY;
                if (workerEnv.GITHUB_ORG) process.env.GITHUB_ORG = workerEnv.GITHUB_ORG;
            }

            const container = await getContainer(
                workerEnv.CACHE || null,
                workerEnv.SCORES_KV || null,
                workerEnv.MEMBERS_KV || null,
                workerEnv.ATTENDANCE_KV || null,
                workerEnv.DB || null,
            );
            const cradle = container.cradle;

            // Precompute leaderboard snapshots
            await cradle.scoreAggregationService.precomputeSnapshots();

            console.log("Cron completed: leaderboard snapshots precomputed");
        } catch (e: any) {
            console.error("Cron error:", e?.message || e, e?.stack);
        }
    },
};

// ─── Cloudflare Types ───────────────────────────────────────

interface ScheduledEvent {
    scheduledTime: number;
    cron: string;
}

interface ExecutionContext {
    waitUntil(promise: Promise<any>): void;
    passThroughOnException(): void;
}
