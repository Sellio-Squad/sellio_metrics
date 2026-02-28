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
 *   GET  /api/observability/stats
 *   GET  /api/observability/calls
 *   DELETE /api/observability/calls
 *   POST /api/webhooks/github
 */

import type { AwilixContainer } from "awilix";
import type { Cradle } from "./core/container";

// ─── Worker Env Bindings ────────────────────────────────────

interface WorkerEnv {
    APP_ID: string;
    INSTALLATION_ID: string;
    APP_PRIVATE_KEY: string;
    GITHUB_ORG?: string;
    LOG_LEVEL?: string;
    NODE_ENV?: string;
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

function getContainer(): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = (async () => {
            // Dynamic import so env.ts reads process.env AFTER we populate it
            const { createContainer, asFunction, asClass, InjectionMode } = await import("awilix");
            const { env } = await import("./config/env");
            const { createGitHubClient } = await import("./infra/github/github.client");
            const { attachTrackingHooks } = await import("./infra/github/tracked-github.client");
            const { createRedisClient } = await import("./infra/cache/cache.client");
            const { CacheService } = await import("./infra/cache/cache.service");
            const { RateLimitGuard } = await import("./infra/github/rate-limit-guard");
            const { CachedGitHubClient } = await import("./infra/github/cached-github.client");
            const { ReposService } = await import("./modules/repos/repos.service");
            const { MetricsService } = await import("./modules/metrics/metrics.service");
            const { LeaderboardService } = await import("./modules/metrics/leaderboard.service");
            const { ObservabilityService } = await import("./modules/observability/observability.service");

            const logger = createConsoleLogger();

            const container = createContainer<Cradle>({
                injectionMode: InjectionMode.PROXY,
            });

            container.register({
                env: asFunction(() => env).singleton(),
                logger: asFunction(() => logger).singleton(),

                observabilityService: asFunction(({ logger }: Cradle) =>
                    new ObservabilityService({ logger }),
                ).singleton(),

                githubClient: asFunction(({ env, observabilityService }: Cradle) => {
                    const client = createGitHubClient({ env });
                    attachTrackingHooks(client, observabilityService);
                    return client;
                }).singleton(),

                redisClient: asFunction(({ env, logger }: Cradle) =>
                    createRedisClient({ redisUrl: env.redisUrl, logger }),
                ).singleton(),

                cacheService: asFunction(({ redisClient, logger }: Cradle) =>
                    new CacheService({ redisClient, logger }),
                ).singleton(),

                rateLimitGuard: asFunction(({ logger, observabilityService, env }: Cradle) =>
                    new RateLimitGuard({
                        logger,
                        observabilityService,
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

async function handleObservabilityStats(cradle: Cradle): Promise<Response> {
    const stats = cradle.observabilityService.getStats();
    const cacheStats = await cradle.cacheService.getStats();
    return json({ ...stats, cacheStats });
}

async function handleObservabilityCalls(cradle: Cradle, url: URL): Promise<Response> {
    const source = url.searchParams.get("source") as "internal" | "github" | "google" | "external" | "cache" | undefined || undefined;
    const limit = parseInt(url.searchParams.get("limit") || "100", 10);
    const offset = parseInt(url.searchParams.get("offset") || "0", 10);
    const result = cradle.observabilityService.getRecentCalls(limit, offset, source);
    return json({ total: result.total, count: result.calls.length, calls: result.calls });
}

async function handleClearCalls(cradle: Cradle): Promise<Response> {
    cradle.observabilityService.clear();
    return json({ status: "cleared" });
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
    if (pathname === "/api/observability/stats") return { handler: "obs-stats" };
    if (pathname === "/api/observability/calls") return { handler: "obs-calls" };
    if (pathname === "/api/webhooks/github") return { handler: "webhook" };

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
        }

        try {
            const container = await getContainer();
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

                case "obs-stats":
                    return handleObservabilityStats(cradle);

                case "obs-calls":
                    if (request.method === "DELETE") return handleClearCalls(cradle);
                    return handleObservabilityCalls(cradle, url);

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
