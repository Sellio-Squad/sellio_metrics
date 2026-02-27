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
    reposService: ReposService;
    metricsService: MetricsService;
    leaderboardService: LeaderboardService;
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

        // Infrastructure
        githubClient: asFunction(createGitHubClient).singleton(),

        // Module services
        reposService: asClass(ReposService).singleton(),
        metricsService: asClass(MetricsService).singleton(),
        leaderboardService: asClass(LeaderboardService).singleton(),
    });

    return container;
}
