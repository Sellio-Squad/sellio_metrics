/**
 * Sellio Metrics Backend — DI Container
 *
 * Awilix-based dependency injection container.
 * All services and clients are registered here and resolved by name.
 *
 * Convention: register as camelCase, resolve via `cradle.serviceName`.
 */

import {
    createContainer,
    asClass,
    asFunction,
    InjectionMode,
    AwilixContainer,
} from "awilix";

import { createGitHubClient, GitHubClient } from "../infra/github/github.client";
import { attachTrackingHooks } from "../infra/github/tracked-github.client";
import { createRedisClient, RedisClient } from "../infra/cache/cache.client";
import { CacheService } from "../infra/cache/cache.service";
import { RateLimitGuard } from "../infra/github/rate-limit-guard";
import { CachedGitHubClient } from "../infra/github/cached-github.client";
import { ReposService } from "../modules/repos/repos.service";
import { MetricsService } from "../modules/metrics/metrics.service";
import { LeaderboardService } from "../modules/metrics/leaderboard.service";
import { ObservabilityService } from "../modules/observability/observability.service";
import { env } from "../config/env";
import { logger } from "./logger";

// ─── Container Shape ────────────────────────────────────────

export interface Cradle {
    env: typeof env;
    logger: typeof logger;
    githubClient: GitHubClient;
    redisClient: RedisClient;
    cacheService: CacheService;
    rateLimitGuard: RateLimitGuard;
    cachedGithubClient: CachedGitHubClient;
    reposService: ReposService;
    metricsService: MetricsService;
    leaderboardService: LeaderboardService;
    observabilityService: ObservabilityService;
}

// ─── Builder ────────────────────────────────────────────────

export function buildContainer(): AwilixContainer<Cradle> {
    const container = createContainer<Cradle>({
        injectionMode: InjectionMode.PROXY,
    });

    container.register({
        // Config & Logging (singletons — plain values)
        env: asFunction(() => env).singleton(),
        logger: asFunction(() => logger).singleton(),

        // Observability (registered early — other infra depends on it)
        observabilityService: asFunction(({ logger }) => {
            return new ObservabilityService({ logger });
        }).singleton(),

        // Infrastructure: GitHub client with tracking hooks
        githubClient: asFunction(({ env, observabilityService }) => {
            const client = createGitHubClient({ env });
            attachTrackingHooks(client, observabilityService);
            return client;
        }).singleton(),

        // Infrastructure: Redis client (gracefully degrades to null)
        redisClient: asFunction(({ env, logger }) => {
            return createRedisClient({ redisUrl: env.redisUrl, logger });
        }).singleton(),

        // Infrastructure: Cache service (wraps Redis)
        cacheService: asFunction(({ redisClient, logger }) => {
            return new CacheService({ redisClient, logger });
        }).singleton(),

        // Infrastructure: Rate limit guard
        rateLimitGuard: asFunction(({ logger, observabilityService, env }) => {
            return new RateLimitGuard({
                logger,
                observabilityService,
                githubRateLimitThreshold: env.githubRateLimitThreshold,
            });
        }).singleton(),

        // Infrastructure: Cached GitHub client (cache-first wrapper)
        // Single responsibility: only caching concern — no observability coupling.
        // Cache stats come from CacheService.getStats(),
        // per-request tracking from tracked-github.client hooks.
        cachedGithubClient: asFunction(({
            githubClient,
            cacheService,
            rateLimitGuard,
            logger,
        }) => {
            return new CachedGitHubClient({
                githubClient,
                cacheService,
                rateLimitGuard,
                logger,
            });
        }).singleton(),

        // Module services
        reposService: asClass(ReposService).singleton(),
        metricsService: asClass(MetricsService).singleton(),
        leaderboardService: asClass(LeaderboardService).singleton(),
    });

    return container;
}
