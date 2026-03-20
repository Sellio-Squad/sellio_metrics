/**
 * Sellio Metrics — DI Container Factory
 *
 * Builds and returns a lazy singleton Awilix container, wiring all
 * services with the Cloudflare env bindings (KV namespaces, D1).
 *
 * Extracted from worker.ts for maintainability and testability.
 */

import type { AwilixContainer } from "awilix";
import type { Cradle } from "./container";
import type { KVNamespace } from "../infra/cache/cache.service";
import type { D1Database } from "../infra/database/d1.service";
import { createConsoleLogger } from "./console-logger";
import { CacheRegistry } from "../infra/cache/cache-registry";

let containerPromise: Promise<AwilixContainer<Cradle>> | null = null;

export function getContainer(
    kvNamespace: KVNamespace | null,
    scoresKv: KVNamespace | null,
    membersKv: KVNamespace | null,
    attendanceKv: KVNamespace | null,
    d1Database: D1Database | null,
): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = buildContainer(kvNamespace, scoresKv, membersKv, attendanceKv, d1Database);
    }
    return containerPromise;
}

async function buildContainer(
    kvNamespace: KVNamespace | null,
    scoresKv: KVNamespace | null,
    membersKv: KVNamespace | null,
    attendanceKv: KVNamespace | null,
    d1Database: D1Database | null,
): Promise<AwilixContainer<Cradle>> {
    const { createContainer, asFunction, asClass, InjectionMode } = await import("awilix");
    const { env } = await import("../config/env");
    const { createGitHubClient } = await import("../infra/github/github.client");
    const { CacheService } = await import("../infra/cache/cache.service");
    const { D1Service } = await import("../infra/database/d1.service");
    const { RateLimitGuard } = await import("../infra/github/rate-limit-guard");
    const { CachedGitHubClient } = await import("../infra/github/cached-github.client");
    const { ReposService } = await import("../modules/repos/repos.service");
    const { PrFetcherService } = await import("../modules/metrics/pr-fetcher.service");
    const { OpenPrsService } = await import("../modules/prs/open-prs.service");
    const { GoogleMeetClient } = await import("../infra/google/google-meet.client");
    const { MeetingsService } = await import("../modules/meetings/meetings.service");
    const { WorkspaceEventsClient } = await import("../infra/google/workspace-events.client");
    const { MeetEventsService } = await import("../modules/meet-events/meet-events.service");
    const { LogsService } = await import("../modules/logs/logs.service");
    const { PointsRulesService } = await import("../modules/points/points-rules.service");
    const { ScoreAggregationService } = await import("../modules/scores/score-aggregation.service");
    const { D1RelationalService } = await import("../infra/database/d1-relational.service");
    const { AttendanceService } = await import("../modules/attendance/attendance.service");

    const logger = createConsoleLogger();
    const container = createContainer<Cradle>({ injectionMode: InjectionMode.PROXY });

    // Build a single CacheRegistry so all namespaces live in one place
    const cacheRegistry = new CacheRegistry({
        generalKv:    kvNamespace,
        scoresKv,
        membersKv,
        attendanceKv,
        logger,
    });

    container.register({
        env: asFunction(() => env).singleton(),
        logger: asFunction(() => logger).singleton(),

        githubClient: asFunction(({ env }: Cradle) =>
            createGitHubClient({ env }),
        ).singleton(),

        // ─── Cache (registry + backward-compat aliases) ───────────────────
        kvNamespace: asFunction(() => kvNamespace).singleton(),
        cache: asFunction(() => cacheRegistry).singleton(),

        // Aliases — services that use these names still work unchanged
        cacheService:    asFunction(({ cache }: Cradle) => cache.general).singleton(),
        scoresKvCache:   asFunction(({ cache }: Cradle) => cache.scores).singleton(),
        membersKvCache:  asFunction(({ cache }: Cradle) => cache.members).singleton(),
        attendanceKvCache: asFunction(({ cache }: Cradle) => cache.attendance).singleton(),

        // D1 Database
        d1Service: asFunction(({ logger }: Cradle) =>
            new D1Service({ d1Database, logger }),
        ).singleton(),

        d1RelationalService: asFunction(({ logger }: Cradle) =>
            new D1RelationalService({ d1Database, logger }),
        ).singleton(),

        rateLimitGuard: asFunction(({ logger, env }: Cradle) =>
            new RateLimitGuard({ logger, githubRateLimitThreshold: env.githubRateLimitThreshold }),
        ).singleton(),

        cachedGithubClient: asFunction(({ githubClient, cacheService, membersKvCache, rateLimitGuard, logger }: Cradle) =>
            new CachedGitHubClient({ githubClient, cacheService, membersKvCache, rateLimitGuard, logger }),
        ).singleton(),

        reposService: asClass(ReposService).singleton(),
        logsService: asClass(LogsService).singleton(),

        // Metrics
        prFetcherService: asClass(PrFetcherService).singleton(),
        openPrsService: asClass(OpenPrsService).singleton(),

        pointsRulesService: asFunction(({ d1Service, scoresKvCache, logger }: Cradle) =>
            new PointsRulesService({ d1Service, scoresKvCache, logger }),
        ).singleton(),

        scoreAggregationService: asFunction(({ d1RelationalService, scoresKvCache, logger }: Cradle) =>
            new ScoreAggregationService({ d1RelationalService, scoresKvCache, logger }),
        ).singleton(),

        attendanceService: asFunction(({ d1RelationalService, attendanceKvCache, logger }: Cradle) =>
            new AttendanceService({ d1RelationalService, attendanceKvCache, logger }),
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
}
