/**
 * Sellio Metrics — Cloudflare Worker Entry Point
 *
 * Thin HTTP router. Each handler has a single job: parse input,
 * call the right service, return a response.
 *
 * Architecture:
 *   PrFetcherService    — fetches & enriches PRs from GitHub
 *   ResultCacheService  — typed KV get/set for computed results
 *   calculateLeaderboard() — pure fn: PrMetric[] → LeaderboardEntry[]
 *   calculateMemberStatus() — pure fn: PrMetric[] + orgMembers → MemberStatus[]
 *
 * Routes:
 *   GET  /api/ping
 *   GET  /api/health
 *   GET  /api/repos
 *   GET  /api/metrics/:owner/:repo/prs
 *   GET  /api/metrics/:owner/:repo/leaderboard
 *   GET  /api/metrics/:owner/:repo/members
 *   POST /api/webhooks/github      (cache invalidation)
 *   GET|POST|DELETE /api/meetings/*
 *   GET|POST|DELETE /api/meet-events/*
 *   GET  /api/debug/auth
 *   GET  /api/debug/meet-subscribe
 *   GET  /api/debug/cache-quota
 */

import type { AwilixContainer } from "awilix";
import type { Cradle } from "./core/container";
import type { KVNamespace } from "./infra/cache/cache.service";

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

function getContainer(kvNamespace: KVNamespace | null): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = (async () => {
            const { createContainer, asFunction, asClass, InjectionMode } = await import("awilix");
            const { env } = await import("./config/env");
            const { createGitHubClient } = await import("./infra/github/github.client");
            const { CacheService } = await import("./infra/cache/cache.service");
            const { RateLimitGuard } = await import("./infra/github/rate-limit-guard");
            const { CachedGitHubClient } = await import("./infra/github/cached-github.client");
            const { ReposService } = await import("./modules/repos/repos.service");
            const { PrFetcherService } = await import("./modules/metrics/pr-fetcher.service");
            const { ResultCacheService } = await import("./modules/metrics/result-cache.service");
            const { GoogleMeetClient } = await import("./infra/google/google-meet.client");
            const { MeetingsService } = await import("./modules/meetings/meetings.service");
            const { WorkspaceEventsClient } = await import("./infra/google/workspace-events.client");
            const { MeetEventsService } = await import("./modules/meet-events/meet-events.service");

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

                rateLimitGuard: asFunction(({ logger, env }: Cradle) =>
                    new RateLimitGuard({ logger, githubRateLimitThreshold: env.githubRateLimitThreshold }),
                ).singleton(),

                cachedGithubClient: asFunction(({ githubClient, cacheService, rateLimitGuard, logger }: Cradle) =>
                    new CachedGitHubClient({ githubClient, cacheService, rateLimitGuard, logger }),
                ).singleton(),

                reposService: asClass(ReposService).singleton(),

                // Metrics: three focused services
                prFetcherService: asClass(PrFetcherService).singleton(),
                resultCacheService: asClass(ResultCacheService).singleton(),

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
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
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
    });
}

async function handleRepos(cradle: Cradle, url: URL): Promise<Response> {
    const org = url.searchParams.get("org") || cradle.env.org;
    const repos = await cradle.reposService.listByOrg(org);
    return json({ org, count: repos.length, repos });
}

/**
 * GET /api/metrics/:owner/:repo/leaderboard
 *
 * Orchestration (handler's only job):
 *   1. Check cache        → ResultCacheService
 *   2. If miss: fetch PRs → PrFetcherService
 *   3. Compute            → calculateLeaderboard() (pure fn)
 *   4. Cache result       → ResultCacheService
 *   5. Return JSON
 */
async function handleLeaderboard(cradle: Cradle, owner: string, repo: string, url: URL): Promise<Response> {
    const { prFetcherService, resultCacheService } = cradle;
    const { calculateLeaderboard } = await import("./modules/metrics/leaderboard.calculator");
    const since = url.searchParams.get("since");
    const until = url.searchParams.get("until");

    // Only use cache when no date filters are applied
    if (!since && !until) {
        const cached = await resultCacheService.getLeaderboard(owner, repo);
        if (cached) return json(cached);
    }

    const allPrs = await prFetcherService.fetch(owner, repo);

    // Apply optional date filter in-memory
    const prs = filterPrsByDate(allPrs, since, until);
    const entries = calculateLeaderboard(prs);
    const cachedAt = new Date().toISOString();

    // Only cache unfiltered results
    if (!since && !until) {
        await resultCacheService.setLeaderboard(owner, repo, entries);
    }
    return json({ owner, repo, cachedAt, since: since ?? null, until: until ?? null, data: entries });
}

/**
 * GET /api/metrics/:owner/:repo/members
 *
 * Orchestration:
 *   1. Check cache         → ResultCacheService
 *   2. If miss: fetch PRs  → PrFetcherService
 *              fetch org members → CachedGitHubClient (cached 24h)
 *   3. Compute             → calculateMemberStatus() (pure fn)
 *   4. Cache result        → ResultCacheService
 *   5. Return JSON
 */
async function handleMembers(cradle: Cradle, owner: string, repo: string, url: URL): Promise<Response> {
    const { prFetcherService, resultCacheService, cachedGithubClient, env } = cradle;
    const { calculateMemberStatus } = await import("./modules/metrics/members.calculator");
    const since = url.searchParams.get("since");
    const until = url.searchParams.get("until");

    // Only use cache when no date filters are applied
    if (!since && !until) {
        const cached = await resultCacheService.getMembers(owner, repo);
        if (cached) return json(cached);
    }

    const [allPrs, orgMembers] = await Promise.all([
        prFetcherService.fetch(owner, repo),
        cachedGithubClient.listOrgMembers(env.org),
    ]);
    // Apply optional date filter in-memory
    const prs = filterPrsByDate(allPrs, since, until);
    const members = calculateMemberStatus(prs, orgMembers);
    const cachedAt = new Date().toISOString();

    // Only cache unfiltered results
    if (!since && !until) {
        await resultCacheService.setMembers(owner, repo, members);
    }
    return json({ owner, repo, cachedAt, since: since ?? null, until: until ?? null, data: members });
}

/**
 * GET /api/metrics/:owner/:repo/prs?state=open|all
 * Returns enriched PR metrics for the frontend.
 * state=open   → only open/pending/approved PRs (fast, cached separately)
 * state=all    → all PRs (default)
 */
async function handlePrs(cradle: Cradle, owner: string, repo: string, url: URL): Promise<Response> {
    const { prFetcherService, resultCacheService } = cradle;
    const state = (url.searchParams.get("state") || "all") as "all" | "open" | "closed";
    const since = url.searchParams.get("since");
    const until = url.searchParams.get("until");

    let prs: any[];
    if (!since && !until) {
        // Try cache for unfiltered requests
        const cached = await resultCacheService.getPrMetrics(owner, repo, state);
        if (cached) return json({ owner, repo, cachedAt: "cached", state, data: cached });
        prs = await prFetcherService.fetch(owner, repo, state);
        await resultCacheService.setPrMetrics(owner, repo, state, prs as any);
    } else {
        // Always fetch + filter when date range specified
        prs = await prFetcherService.fetch(owner, repo, state);
        prs = filterPrsByDate(prs as any, since, until);
    }

    const cachedAt = new Date().toISOString();
    return json({ owner, repo, cachedAt, state, since: since ?? null, until: until ?? null, data: prs });
}

/** Filter PrMetric[] by optional since/until (ISO date strings). */
function filterPrsByDate(prs: any[], since: string | null, until: string | null): any[] {
    if (!since && !until) return prs;
    const sinceTs = since ? new Date(since).getTime() : 0;
    const untilTs = until ? new Date(until).getTime() : Infinity;
    return prs.filter((pr) => {
        const openedAt = new Date(pr.opened_at).getTime();
        return openedAt >= sinceTs && openedAt <= untilTs;
    });
}

/**
 * POST /api/webhooks/github
 * Invalidates result cache when GitHub pushes a PR event.
 */
async function handleWebhook(cradle: Cradle, request: Request): Promise<Response> {
    const event = request.headers.get("x-github-event");
    const RELEVANT = new Set(["pull_request", "pull_request_review", "issue_comment", "pull_request_review_comment"]);

    if (!event || !RELEVANT.has(event)) return json({ ignored: true, event });

    const payload = await request.json() as any;
    const repo = payload?.repository;
    if (!repo?.full_name) return json({ ignored: true, reason: "no repo" });

    const [owner, repoName] = repo.full_name.split("/");
    await cradle.resultCacheService.invalidatePrMetrics(owner, repoName);

    return json({ ok: true, event, repo: repo.full_name, invalidated: true });
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
    const [cacheStatus, repos, orgMembers, token] = await Promise.all([
        cradle.resultCacheService.getStatus(owner, repoName),
        cradle.cacheService.get<any>(`github:repos:${cradle.env.org}`),
        cradle.cacheService.get<any>(`github:org-members:${cradle.env.org}`),
        cradle.cacheService.get<any>("google_oauth_tokens"),
    ]);

    return json({
        kvFreeWriteLimit: 1000,
        kvResetAtUtc: midnight.toISOString(),
        kvSecondsToReset: secondsToReset,
        kvResetNote: "Cloudflare KV free tier resets daily at midnight UTC",
        maxWritesPerRequest: 3,
        strategy: "Only computed results are cached (leaderboard + members + metrics). No per-PR writes.",
        cachedResults: {
            [`result:metrics:${defaultRepo}:all`]: { hit: cacheStatus.metrics, cachedAt: cacheStatus.metricsAge },
            [`result:leaderboard:${defaultRepo}`]: { hit: cacheStatus.leaderboard, cachedAt: cacheStatus.leaderboardAge },
            [`result:members:${defaultRepo}`]: { hit: cacheStatus.members, cachedAt: cacheStatus.membersAge },
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
    // Static routes first (fastest)
    if (p === "/api/ping") return { handler: "ping" };
    if (p === "/api/health") return { handler: "health" };
    if (p === "/api/repos") return { handler: "repos" };
    if (p === "/api/webhooks/github") return { handler: "webhook" };
    if (p === "/api/debug/auth") return { handler: "debugAuth" };
    if (p === "/api/debug/meet-subscribe") return { handler: "debugMeetSubscribe" };
    if (p === "/api/debug/cache-quota") return { handler: "debugCacheQuota" };

    if (p.startsWith("/api/meetings")) return { handler: "meetings", params: { path: p.replace("/api/meetings", "") } };
    if (p.startsWith("/api/meet-events")) return { handler: "meetEvents", params: { path: p.replace("/api/meet-events", "") } };

    // Parameterised metric sub-routes (order matters: specifc before generic)
    const lb = p.match(/^\/api\/metrics\/([^/]+)\/([^/]+)\/leaderboard$/);
    if (lb) return { handler: "leaderboard", params: { owner: lb[1], repo: lb[2] } };

    const mb = p.match(/^\/api\/metrics\/([^/]+)\/([^/]+)\/members$/);
    if (mb) return { handler: "members", params: { owner: mb[1], repo: mb[2] } };

    const prs = p.match(/^\/api\/metrics\/([^/]+)\/([^/]+)\/prs$/);
    if (prs) return { handler: "prs", params: { owner: prs[1], repo: prs[2] } };

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

            const container = await getContainer(workerEnv.CACHE || null);
            const cradle = container.cradle;
            const route = matchRoute(url.pathname);

            if (!route) return err("Not Found", 404);

            switch (route.handler) {
                case "health": return handleHealth(cradle);
                case "repos": return handleRepos(cradle, url);
                case "leaderboard":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleLeaderboard(cradle, route.params!.owner, route.params!.repo, url);
                case "members":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handleMembers(cradle, route.params!.owner, route.params!.repo, url);
                case "prs":
                    if (request.method !== "GET") return err("Method Not Allowed", 405);
                    return handlePrs(cradle, route.params!.owner, route.params!.repo, url);
                case "webhook":
                    if (request.method !== "POST") return err("Method Not Allowed", 405);
                    return handleWebhook(cradle, request);
                case "meetings": return handleMeetings(cradle, request, route.params!.path, url);
                case "meetEvents": return handleMeetEvents(cradle, request, route.params!.path, url);
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
};
