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
    webhookQueue: any | null = null,
): Promise<AwilixContainer<Cradle>> {
    if (!containerPromise) {
        containerPromise = buildContainer(kvNamespace, scoresKv, membersKv, attendanceKv, d1Database, webhookQueue);
    }
    return containerPromise;
}

async function buildContainer(
    kvNamespace: KVNamespace | null,
    scoresKv: KVNamespace | null,
    membersKv: KVNamespace | null,
    attendanceKv: KVNamespace | null,
    d1Database: D1Database | null,
    webhookQueue: any | null = null,
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
    const { LogsService } = await import("../modules/logs/logs.service");
    const { PointsRulesService } = await import("../modules/points/points-rules.service");
    const { ScoreAggregationService } = await import("../modules/scores/score-aggregation.service");
    const { ReposRepository } = await import("../modules/repos/repos.repository");
    const { PrsRepository } = await import("../modules/prs/prs.repository");
    const { CommentsRepository } = await import("../modules/prs/comments.repository");
    const { ScoresRepository } = await import("../modules/scores/scores.repository");
    const { DeveloperRepository } = await import("../modules/developers/developer.repository");
    const { MeetingsRepository } = await import("../modules/meetings/meetings.repository");
    const { WebhookHandlerService } = await import("../modules/meetings/webhook-handler.service");
    const { WebhookService } = await import("../modules/webhook/webhook.service");
    const { GeminiClient } = await import("../infra/ai/gemini.client");
    const { ReviewService } = await import("../modules/review/review.service");

    let isLogging = false;
    let logsServiceRef: any = null;

    const logger = createConsoleLogger({}, (level, msg, obj) => {
        if (!logsServiceRef || isLogging) return;
        isLogging = true;
        
        try {
            const objAny = obj as any;
            if (objAny && objAny.module === "logs") {
                return;
            }

            let category = "system";
            if (objAny) {
               if (objAny.err?.message?.includes("github") || objAny.module === "github" || objAny.module === "webhook" || objAny.module === "sync" || objAny.module === "repos" || objAny.module === "prs") category = "github";
               if (objAny.module === "google-meet" || objAny.module === "meetings") category = "googleMeet";
               if (objAny.category) category = objAny.category;
            }

            logsServiceRef.log(msg, level as any, category, obj).catch(() => {});
        } finally {
            isLogging = false;
        }
    });
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

        developerRepo: asFunction(({ logger }: Cradle) => new DeveloperRepository(d1Database, logger)).singleton(),
        reposRepo: asFunction(({ logger }: Cradle) => new ReposRepository(d1Database, logger)).singleton(),
        prsRepo: asFunction(({ logger, developerRepo }: Cradle) => new PrsRepository(d1Database, logger, developerRepo)).singleton(),
        commentsRepo: asFunction(({ logger, developerRepo }: Cradle) => new CommentsRepository(d1Database, logger, developerRepo)).singleton(),
        scoresRepo: asFunction(({ logger }: Cradle) => new ScoresRepository(d1Database, logger)).singleton(),
        meetingsRepo: asFunction(({ logger }: Cradle) => new MeetingsRepository(d1Database, logger)).singleton(),

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

        scoreAggregationService: asFunction(({ scoresRepo, scoresKvCache, logger }: Cradle) =>
            new ScoreAggregationService({ scoresRepo, scoresKvCache, logger }),
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
        meetingsService: asFunction(({ logger, googleMeetClient, meetingsRepo, env }: Cradle) =>
            new MeetingsService(googleMeetClient, meetingsRepo, env.googlePubsubTopic, logger),
        ).singleton(),
        webhookHandlerService: asFunction(({ logger, googleMeetClient }: Cradle) =>
            new WebhookHandlerService({ logger, googleMeetClient }),
        ).singleton(),

        // Webhook
        webhookQueue: asFunction(() => webhookQueue).singleton(),
        webhookService: asFunction(({ logger, reposRepo, developerRepo, prsRepo, commentsRepo, openPrsService, cache, cachedGithubClient, env }: Cradle) =>
            new WebhookService({ logger, reposRepo, developerRepo, prsRepo, commentsRepo, openPrsService, cache, cachedGithubClient, env }),
        ).singleton(),

        // AI
        geminiClient: asFunction(({ env, logger }: Cradle) =>
            new GeminiClient({ geminiApiKey: env.geminiApiKey, logger }),
        ).singleton(),

        // Review
        reviewService: asFunction(({ cachedGithubClient, geminiClient, logger }: Cradle) =>
            new ReviewService({ cachedGithubClient, geminiClient, logger }),
        ).singleton(),
    });

    try {
        logsServiceRef = container.resolve("logsService");
    } catch (e) {
        /* ignore */
    }

    return container;
}
