/**
 * Sellio Metrics Backend — DI Container (Cradle interface only)
 *
 * Registration is now done in container-factory.ts where env bindings are available.
 * This file defines the Cradle shape for type-safe dependency injection.
 */

import type { CacheService, KVNamespace } from "../infra/cache/cache.service";
import type { CacheRegistry } from "../infra/cache/cache-registry";
import type { D1Service } from "../infra/database/d1.service";
import type { ReposRepository } from "../modules/repos/repos.repository";
import type { PrsRepository } from "../modules/prs/prs.repository";
import type { CommentsRepository } from "../modules/prs/comments.repository";
import type { CommitsRepository } from "../modules/commits/commits.repository";
import type { ScoresRepository } from "../modules/scores/scores.repository";
import type { DeveloperRepository } from "../modules/developers/developer.repository";
import type { MeetingsRepository } from "../modules/meetings/meetings.repository";
import type { RegularSchedulesRepository } from "../modules/meetings/regular-schedules.repository";
import type { RateLimitGuard } from "../infra/github/rate-limit-guard";
import type { CachedGitHubClient } from "../infra/github/cached-github.client";
import type { ReposService } from "../modules/repos/repos.service";
import type { PrFetcherService } from "../modules/metrics/pr-fetcher.service";
import type { OpenPrsService } from "../modules/prs/open-prs.service";
import type { OpenIssuesService } from "../modules/issues/issues.service";
import type { GoogleMeetClient } from "../infra/google/google-meet.client";
import type { MeetingsService } from "../modules/meetings/meetings.service";
import type { WebhookHandlerService } from "../modules/meetings/webhook-handler.service";
import type { LogsService } from "../modules/logs/logs.service";
import type { PointsRulesService } from "../modules/points/points-rules.service";
import type { ScoreAggregationService } from "../modules/scores/score-aggregation.service";
import type { WebhookService } from "../modules/webhook/webhook.service";
import type { env } from "../config/env";
import type { GeminiClient } from "../infra/ai/gemini.client";
import type { PrContextFetcher } from "../modules/review/pr-context-fetcher";
import type { ReviewService } from "../modules/review/review.service";
import type { Logger } from "./logger";

// ─── Container Shape ────────────────────────────────────────

export interface Cradle {
    env: typeof env;
    logger: Logger;

    // Infrastructure — GitHub
    githubClient: any;
    rateLimitGuard: RateLimitGuard;
    cachedGithubClient: CachedGitHubClient;

    // Infrastructure — Cache (single registry, named namespaces)
    cache: CacheRegistry;

    /**
     * @deprecated Use `cache.general` instead.
     * Kept for backward compatibility with services not yet migrated.
     */
    cacheService: CacheService;
    /** @deprecated Use `cache.scores` */
    scoresKvCache: CacheService;
    /** @deprecated Use `cache.members` */
    membersKvCache: CacheService;
    /** @deprecated Use `cache.attendance` */
    attendanceKvCache: CacheService;
    kvNamespace: KVNamespace | null;

    // Infrastructure — D1
    d1Service: D1Service;
    developerRepo: DeveloperRepository;
    reposRepo: ReposRepository;
    prsRepo: PrsRepository;
    commentsRepo: CommentsRepository;
    commitsRepo: CommitsRepository;
    scoresRepo: ScoresRepository;
    meetingsRepo: MeetingsRepository;
    regularSchedulesRepo: RegularSchedulesRepository;

    // Repos
    reposService: ReposService;

    // Metrics
    prFetcherService: PrFetcherService;

    // PRs
    openPrsService: OpenPrsService;

    // Issues
    openIssuesService: OpenIssuesService;

    // Scoring
    pointsRulesService: PointsRulesService;
    scoreAggregationService: ScoreAggregationService;

    // Google Meet
    googleMeetClient: GoogleMeetClient;
    meetingsService: MeetingsService;
    webhookHandlerService: WebhookHandlerService;

    // Logs
    logsService: LogsService;

    // Webhook
    webhookService: WebhookService;
    webhookQueue: any | null;

    // AI
    geminiClient: GeminiClient;

    // Review
    prContextFetcher: PrContextFetcher;
    reviewService: ReviewService;
}
