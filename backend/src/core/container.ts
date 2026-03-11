/**
 * Sellio Metrics Backend — DI Container
 *
 * Registers all services following Single Responsibility Principle.
 *
 * Metrics module services:
 *   PrFetcherService   — fetches & enriches PRs from GitHub (no caching)
 *   ResultCacheService — typed KV get/set for computed results (no compute)
 *   leaderboard.calculator / members.calculator — pure fns, not registered
 *     (imported directly in handlers — they have no injectable dependencies)
 */

import {
    createContainer,
    asClass,
    asFunction,
    InjectionMode,
    type AwilixContainer,
} from "awilix";

import { createGitHubClient, type GitHubClient } from "../infra/github/github.client";
import { CacheService, type KVNamespace } from "../infra/cache/cache.service";
import { RateLimitGuard } from "../infra/github/rate-limit-guard";
import { CachedGitHubClient } from "../infra/github/cached-github.client";
import { ReposService } from "../modules/repos/repos.service";
import { PrFetcherService } from "../modules/metrics/pr-fetcher.service";
import { ResultCacheService } from "../modules/metrics/result-cache.service";
import { GoogleMeetClient } from "../infra/google/google-meet.client";
import { WorkspaceEventsClient } from "../infra/google/workspace-events.client";
import { MeetingsService } from "../modules/meetings/meetings.service";
import { MeetEventsService } from "../modules/meet-events/meet-events.service";
import { LogsService } from "../modules/logs/logs.service";
import { env } from "../config/env";
import { logger } from "./logger";

// ─── Container Shape ────────────────────────────────────────

export interface Cradle {
    env: typeof env;
    logger: typeof logger;

    // Infrastructure
    githubClient: GitHubClient;
    kvNamespace: KVNamespace | null;
    cacheService: CacheService;
    rateLimitGuard: RateLimitGuard;
    cachedGithubClient: CachedGitHubClient;

    // Repos
    reposService: ReposService;

    // Metrics — three focused services (calculators are pure fns, not registered)
    prFetcherService: PrFetcherService;
    resultCacheService: ResultCacheService;

    // Google Meet
    googleMeetClient: GoogleMeetClient;
    workspaceEventsClient: WorkspaceEventsClient;
    meetingsService: MeetingsService;
    meetEventsService: MeetEventsService;

    // Logs
    logsService: LogsService;
}

// ─── Builder ────────────────────────────────────────────────

export function buildContainer(kvNamespace: KVNamespace | null = null): AwilixContainer<Cradle> {
    const container = createContainer<Cradle>({ injectionMode: InjectionMode.PROXY });

    container.register({
        // ── Config & Logging ──────────────────────────────
        env: asFunction(() => env).singleton(),
        logger: asFunction(() => logger).singleton(),

        // ── Infrastructure ────────────────────────────────
        githubClient: asFunction(({ env }) =>
            createGitHubClient({ env }),
        ).singleton(),

        kvNamespace: asFunction(() => kvNamespace).singleton(),

        cacheService: asFunction(({ kvNamespace, logger }) =>
            new CacheService({ kvNamespace, logger }),
        ).singleton(),

        rateLimitGuard: asFunction(({ logger, env }) =>
            new RateLimitGuard({ logger, githubRateLimitThreshold: env.githubRateLimitThreshold }),
        ).singleton(),

        cachedGithubClient: asFunction(({ githubClient, cacheService, rateLimitGuard, logger }) =>
            new CachedGitHubClient({ githubClient, cacheService, rateLimitGuard, logger }),
        ).singleton(),

        // ── Repos ─────────────────────────────────────────
        reposService: asClass(ReposService).singleton(),

        // ── Metrics (SRP: each class has one job) ─────────
        prFetcherService: asClass(PrFetcherService).singleton(),
        resultCacheService: asClass(ResultCacheService).singleton(),

        // ── Google Meet ───────────────────────────────────
        googleMeetClient: asFunction(({ logger, env, cacheService }) =>
            new GoogleMeetClient({
                logger,
                clientId: env.googleClientId,
                clientSecret: env.googleClientSecret,
                redirectUri: env.googleRedirectUri,
                cacheService,
            }),
        ).singleton(),

        meetingsService: asClass(MeetingsService).singleton(),

        workspaceEventsClient: asFunction(({ logger, cacheService }) =>
            new WorkspaceEventsClient({ logger, cacheService }),
        ).singleton(),

        meetEventsService: asFunction(({ logger, workspaceEventsClient, cacheService, env }) =>
            new MeetEventsService({
                logger,
                workspaceEventsClient,
                cacheService,
                pubsubTopic: env.googlePubsubTopic,
            }),
        ).singleton(),

        // ── Logs ──────────────────────────────────────────
        logsService: asClass(LogsService).singleton(),
    });

    return container;
}
