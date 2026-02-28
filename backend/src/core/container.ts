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
import { CacheService, KVNamespace } from "../infra/cache/cache.service";
import { RateLimitGuard } from "../infra/github/rate-limit-guard";
import { CachedGitHubClient } from "../infra/github/cached-github.client";
import { ReposService } from "../modules/repos/repos.service";
import { MetricsService } from "../modules/metrics/metrics.service";
import { LeaderboardService } from "../modules/metrics/leaderboard.service";
import { env } from "../config/env";
import { logger } from "./logger";

// ─── Container Shape ────────────────────────────────────────

export interface Cradle {
    env: typeof env;
    logger: typeof logger;
    githubClient: GitHubClient;
    kvNamespace: KVNamespace | null;
    cacheService: CacheService;
    rateLimitGuard: RateLimitGuard;
    cachedGithubClient: CachedGitHubClient;
    reposService: ReposService;
    metricsService: MetricsService;
    leaderboardService: LeaderboardService;
}

// ─── Builder ────────────────────────────────────────────────

export function buildContainer(kvNamespace: KVNamespace | null = null): AwilixContainer<Cradle> {
    const container = createContainer<Cradle>({
        injectionMode: InjectionMode.PROXY,
    });

    container.register({
        // Config & Logging (singletons — plain values)
        env: asFunction(() => env).singleton(),
        logger: asFunction(() => logger).singleton(),

        // Infrastructure: GitHub client (no tracking hooks — Cloudflare provides observability)
        githubClient: asFunction(({ env }) => {
            return createGitHubClient({ env });
        }).singleton(),

        // Infrastructure: Workers KV namespace (passed from worker.ts or null for local dev)
        kvNamespace: asFunction(() => kvNamespace).singleton(),

        // Infrastructure: Cache service (wraps Workers KV)
        cacheService: asFunction(({ kvNamespace, logger }) => {
            return new CacheService({ kvNamespace, logger });
        }).singleton(),

        // Infrastructure: Rate limit guard
        rateLimitGuard: asFunction(({ logger, env }) => {
            return new RateLimitGuard({
                logger,
                githubRateLimitThreshold: env.githubRateLimitThreshold,
            });
        }).singleton(),

        // Infrastructure: Cached GitHub client (cache-first wrapper)
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
