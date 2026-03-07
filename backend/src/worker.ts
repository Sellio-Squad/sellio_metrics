/**
 * Sellio Metrics Backend — Cloudflare Worker Entry Point
 *
 * Workers-native router that bypasses Fastify (pino doesn't bundle
 * correctly with esbuild). Reuses all existing services directly
 * from the Awilix DI container.
 *
 * Routes handled:
 *   GET  /api/health
 *   GET  /api/repos
 *   GET  /api/metrics/:owner/:repo
 *   POST /api/metrics/leaderboard
 *   POST /api/webhooks/github
 */

import type { AwilixContainer } from "awilix";
import type { Cradle } from "./core/container";
import type { KVNamespace } from "./infra/cache/cache.service";

// ─── Worker Env Bindings ────────────────────────────────────

interface WorkerEnv {
    // Secrets (set via dashboard / wrangler secret put)
    APP_ID: string;
    INSTALLATION_ID: string;
    APP_PRIVATE_KEY: string;

    // Vars (set in wrangler.toml [vars])
    GITHUB_ORG?: string;
    LOG_LEVEL?: string;
    NODE_ENV?: string;
    GOOGLE_CLIENT_ID?: string;
    GOOGLE_CLIENT_SECRET?: string;
    GOOGLE_REDIRECT_URI?: string;

    // KV namespace binding
    CACHE: KVNamespace;
}

// ─── Console Logger (pino-compatible API for services) ──────

function createConsoleLogger(bindings: Record<string, unknown> = {}): any {
    const withBindings = (msg: string, extra?: unknown) => {
        const parts = { ...bindings, ...(typeof extra === "object" && extra ? extra : {}) };
        return Object.keys(parts).length > 0 ? `[${JSON.stringify(parts)}] ${msg}` : msg;
    };
    const logger: any = {
        info: (objOrMsg: unknown, msg?: string) => {
            if (typeof objOrMsg === "string") console.log(objOrMsg);
            else console.log(withBindings(msg || "", objOrMsg as Record<string, unknown>));
        },
        warn: (objOrMsg: unknown, msg?: string) => {
            if (typeof objOrMsg === "string") console.warn(objOrMsg);
            else console.warn(withBindings(msg || "", objOrMsg as Record<string, unknown>));
        },
        error: (objOrMsg: unknown, msg?: string) => {
            if (typeof objOrMsg === "string") console.error(objOrMsg);
            else console.error(withBindings(msg || "", objOrMsg as Record<string, unknown>));
        },
        debug: (objOrMsg: unknown, msg?: string) => {
            if (typeof objOrMsg === "string") console.debug(objOrMsg);
            else console.debug(withBindings(msg || "", objOrMsg as Record<string, unknown>));
        },
        fatal: (objOrMsg: unknown, msg?: string) => {
            if (typeof objOrMsg === "string") console.error(`[FATAL] ${objOrMsg}`);
            else console.error(withBindings(`[FATAL] ${msg || ""}`, objOrMsg as Record<string, unknown>));
        },
        trace: () => { /* no-op */ },
        child: (childBindings: Record<string, unknown>) =>
            createConsoleLogger({ ...bindings, ...childBindings }),
        level: "info",
    };
    return logger;
}

// ─── Lazy Container Singleton ───────────────────────────────

let containerPromise: Promise<AwilixContainer<Cradle>> | null = null;

function getContainer(kvNamespace: KVNamespace | null): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = (async () => {
            // Dynamic import so env.ts reads process.env AFTER we populate it
            const { createContainer, asFunction, asClass, InjectionMode } = await import("awilix");
            const { env } = await import("./config/env");
            const { createGitHubClient } = await import("./infra/github/github.client");
            const { CacheService } = await import("./infra/cache/cache.service");
            const { RateLimitGuard } = await import("./infra/github/rate-limit-guard");
            const { CachedGitHubClient } = await import("./infra/github/cached-github.client");
            const { ReposService } = await import("./modules/repos/repos.service");
            const { MetricsService } = await import("./modules/metrics/metrics.service");
            const { LeaderboardService } = await import("./modules/metrics/leaderboard.service");
            const { MembersService } = await import("./modules/members/members.service");
            const { GoogleMeetClient } = await import("./infra/google/google-meet.client");
            const { MeetingsService } = await import("./modules/meetings/meetings.service");

            const logger = createConsoleLogger();

            const container = createContainer<Cradle>({
                injectionMode: InjectionMode.PROXY,
            });

            container.register({
                env: asFunction(() => env).singleton(),
                logger: asFunction(() => logger).singleton(),

                githubClient: asFunction(({ env }: Cradle) => {
                    return createGitHubClient({ env });
                }).singleton(),

                kvNamespace: asFunction(() => kvNamespace).singleton(),

                cacheService: asFunction(({ kvNamespace, logger }: Cradle) =>
                    new CacheService({ kvNamespace, logger }),
                ).singleton(),

                rateLimitGuard: asFunction(({ logger, env }: Cradle) =>
                    new RateLimitGuard({
                        logger,
                        githubRateLimitThreshold: env.githubRateLimitThreshold,
                    }),
                ).singleton(),

                cachedGithubClient: asFunction(({
                    githubClient, cacheService, rateLimitGuard, logger,
                }: Cradle) =>
                    new CachedGitHubClient({ githubClient, cacheService, rateLimitGuard, logger }),
                ).singleton(),

                reposService: asClass(ReposService).singleton(),
                metricsService: asClass(MetricsService).singleton(),
                leaderboardService: asClass(LeaderboardService).singleton(),
                membersService: asClass(MembersService).singleton(),
                googleMeetClient: asFunction(({ logger, env, cacheService }: Cradle) => new GoogleMeetClient({
                    logger,
                    clientId: env.googleClientId,
                    clientSecret: env.googleClientSecret,
                    redirectUri: env.googleRedirectUri,
                    cacheService,
                })).singleton(),
                meetingsService: asClass(MeetingsService).singleton(),
            });

            return container;
        })();
    }
    return containerPromise;
}

// ─── CORS Helpers ───────────────────────────────────────────

const CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
        status,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
}

function errorResponse(message: string, status = 500): Response {
    return json({ error: message }, status);
}

// ─── Route Handlers ─────────────────────────────────────────

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

async function handleMetrics(cradle: Cradle, owner: string, repo: string, url: URL): Promise<Response> {
    const state = (url.searchParams.get("state") || "all") as "all" | "open" | "closed";
    const perPage = parseInt(url.searchParams.get("per_page") || "100", 10);
    const metrics = await cradle.metricsService.fetchPrMetrics(owner, repo, { state, perPage });
    return json({ owner, repo, count: metrics.length, metrics });
}

async function handleLeaderboard(cradle: Cradle, body: any): Promise<Response> {
    const prs = body?.prs;
    if (!Array.isArray(prs)) return errorResponse("Body must contain a 'prs' array", 400);
    const result = cradle.leaderboardService.calculateLeaderboard(prs);
    return json(result);
}

async function handleMembersStatus(cradle: Cradle, request: Request): Promise<Response> {
    if (request.method !== "POST") return errorResponse("Method Not Allowed", 405);
    const body = (await request.json()) as any;
    const prs = body?.prs;
    if (!Array.isArray(prs)) return errorResponse("Body must contain a 'prs' array", 400);
    const orgMembers = await cradle.cachedGithubClient.listOrgMembers(cradle.env.org);
    const result = cradle.membersService.calculateMemberStatus(prs, orgMembers);
    return json(result);
}

async function handleMeetings(cradle: Cradle, request: Request, path: string, url: URL): Promise<Response> {
    const { meetingsService } = cradle;

    if (request.method === "GET") {
        if (path === "/auth-url") return json({ authUrl: meetingsService.getAuthUrl() });
        if (path === "/auth-status") return json({ isReady: await meetingsService.isReady() });
        if (path === "/oauth2callback") {
            const code = url.searchParams.get("code");
            const error = url.searchParams.get("error");
            if (error) return new Response(`<h1>Failed</h1><p>${error}</p>`, { headers: { "Content-Type": "text/html", ...CORS_HEADERS } });
            if (!code) return errorResponse("Missing code", 400);
            try {
                await meetingsService.authorize(code);
                return new Response(`<html><body><h1>Success</h1><script>setTimeout(() => window.close(), 3000);</script></body></html>`, { headers: { "Content-Type": "text/html", ...CORS_HEADERS } });
            } catch {
                return errorResponse("Authentication failed", 500);
            }
        }
        if (path === "/rate-limit") return json(meetingsService.getRateLimitStatus());
        if (path === "/analytics") return json(await meetingsService.getAnalytics());
        if (path === "" || path === "/") return json(await meetingsService.listMeetings());

        const idMatch = path.match(/^\/([^/]+)$/);
        if (idMatch) return json(await meetingsService.getMeeting(idMatch[1]));
        const attMatch = path.match(/^\/([^/]+)\/attendance$/);
        if (attMatch) return json(await meetingsService.getAttendance(attMatch[1]));
    } else if (request.method === "POST") {
        if (path === "/auth-logout") {
            await meetingsService.clearCredentials();
            return json({ success: true });
        }
        if (path === "" || path === "/") {
            const body = await request.json() as any;
            if (!(await meetingsService.isReady())) {
                return new Response(JSON.stringify({ error: "UNAUTHORIZED", message: "Sign in required.", authUrl: meetingsService.getAuthUrl() }), { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } });
            }
            return json(await meetingsService.createMeeting(body.title));
        }
        const endMatch = path.match(/^\/([^/]+)\/end$/);
        if (endMatch) {
            await meetingsService.endMeeting(endMatch[1]);
            return json({ success: true });
        }
    }
    return errorResponse("Not Found", 404);
}

async function handleWebhook(cradle: Cradle, request: Request): Promise<Response> {
    const event = request.headers.get("x-github-event");
    const RELEVANT_EVENTS = new Set([
        "pull_request", "pull_request_review",
        "issue_comment", "pull_request_review_comment",
    ]);

    if (!event || !RELEVANT_EVENTS.has(event)) {
        return json({ ignored: true, event }, 200);
    }

    const payload = await request.json() as any;
    const repo = payload?.repository;
    if (!repo?.full_name) {
        return json({ ignored: true, reason: "no repo" }, 200);
    }

    const [owner, repoName] = repo.full_name.split("/");
    const keysToInvalidate = [
        `result:metrics:${owner}/${repoName}:all`,
        `result:metrics:${owner}/${repoName}:open`,
        `result:metrics:${owner}/${repoName}:closed`,
    ];

    let deleted = 0;
    for (const key of keysToInvalidate) {
        const result = await cradle.cacheService.del(key);
        if (result) deleted++;
    }

    return json({ ok: true, event, repo: repo.full_name, cacheKeysInvalidated: deleted });
}

// ─── URL Pattern Router ─────────────────────────────────────

function matchRoute(pathname: string): { handler: string; params?: Record<string, string> } | null {
    if (pathname === "/api/health") return { handler: "health" };
    if (pathname === "/api/repos") return { handler: "repos" };
    if (pathname === "/api/metrics/leaderboard") return { handler: "leaderboard" };
    if (pathname === "/api/webhooks/github") return { handler: "webhook" };
    if (pathname === "/api/members/status") return { handler: "membersStatus" };
    if (pathname.startsWith("/api/meetings")) {
        return { handler: "meetings", params: { path: pathname.replace("/api/meetings", "") } };
    }

    // /api/metrics/:owner/:repo
    const metricsMatch = pathname.match(/^\/api\/metrics\/([^/]+)\/([^/]+)$/);
    if (metricsMatch) {
        return { handler: "metrics", params: { owner: metricsMatch[1], repo: metricsMatch[2] } };
    }

    return null;
}

// ─── Fetch Handler ──────────────────────────────────────────

export default {
    async fetch(request: Request, workerEnv: WorkerEnv): Promise<Response> {
        // CORS preflight
        if (request.method === "OPTIONS") {
            return new Response(null, { status: 204, headers: CORS_HEADERS });
        }

        // Populate process.env from Worker bindings (once)
        if (!process.env.APP_ID) {
            process.env.APP_ID = workerEnv.APP_ID;
            process.env.INSTALLATION_ID = workerEnv.INSTALLATION_ID;
            process.env.APP_PRIVATE_KEY = workerEnv.APP_PRIVATE_KEY;
            if (workerEnv.GITHUB_ORG) process.env.GITHUB_ORG = workerEnv.GITHUB_ORG;
            if (workerEnv.LOG_LEVEL) process.env.LOG_LEVEL = workerEnv.LOG_LEVEL;
            if (workerEnv.GOOGLE_CLIENT_ID) process.env.GOOGLE_CLIENT_ID = workerEnv.GOOGLE_CLIENT_ID;
            if (workerEnv.GOOGLE_CLIENT_SECRET) process.env.GOOGLE_CLIENT_SECRET = workerEnv.GOOGLE_CLIENT_SECRET;
            if (workerEnv.GOOGLE_REDIRECT_URI) process.env.GOOGLE_REDIRECT_URI = workerEnv.GOOGLE_REDIRECT_URI;
        }

        try {
            const container = await getContainer(workerEnv.CACHE || null);
            const cradle = container.cradle;
            const url = new URL(request.url);
            const route = matchRoute(url.pathname);

            if (!route) return errorResponse("Not Found", 404);

            switch (route.handler) {
                case "health":
                    return handleHealth(cradle);

                case "repos":
                    return handleRepos(cradle, url);

                case "metrics":
                    return handleMetrics(cradle, route.params!.owner, route.params!.repo, url);

                case "leaderboard": {
                    if (request.method !== "POST") return errorResponse("Method Not Allowed", 405);
                    const body = await request.json();
                    return handleLeaderboard(cradle, body);
                }

                case "membersStatus":
                    return handleMembersStatus(cradle, request);

                case "meetings":
                    return handleMeetings(cradle, request, route.params!.path, url);

                case "webhook":
                    if (request.method !== "POST") return errorResponse("Method Not Allowed", 405);
                    return handleWebhook(cradle, request);

                default:
                    return errorResponse("Not Found", 404);
            }
        } catch (err: any) {
            console.error("Worker error:", err?.message || err, err?.stack);
            return errorResponse(err?.message || "Internal Server Error", 500);
        }
    },
};
