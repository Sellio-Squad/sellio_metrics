/**
 * Sellio Metrics Backend — DI Container (Cradle interface only)
 *
 * Registration is now done in worker.ts where env bindings are available.
 * This file defines the Cradle shape for type-safe dependency injection.
 */

import type { CacheService, KVNamespace } from "../infra/cache/cache.service";
import type { D1Service } from "../infra/database/d1.service";
import type { RateLimitGuard } from "../infra/github/rate-limit-guard";
import type { CachedGitHubClient } from "../infra/github/cached-github.client";
import type { ReposService } from "../modules/repos/repos.service";
import type { PrFetcherService } from "../modules/metrics/pr-fetcher.service";
import type { GoogleMeetClient } from "../infra/google/google-meet.client";
import type { WorkspaceEventsClient } from "../infra/google/workspace-events.client";
import type { MeetingsService } from "../modules/meetings/meetings.service";
import type { MeetEventsService } from "../modules/meet-events/meet-events.service";
import type { LogsService } from "../modules/logs/logs.service";
import type { EventsService } from "../modules/events/events.service";
import type { PointsRulesService } from "../modules/points/points-rules.service";
import type { ScoreAggregationService } from "../modules/scores/score-aggregation.service";
import type { AttendanceService } from "../modules/attendance/attendance.service";
import type { env } from "../config/env";
import type { Logger } from "./logger";

// ─── Container Shape ────────────────────────────────────────

export interface Cradle {
    env: typeof env;
    logger: Logger;

    // Infrastructure — core
    githubClient: any;
    kvNamespace: KVNamespace | null;
    cacheService: CacheService;
    rateLimitGuard: RateLimitGuard;
    cachedGithubClient: CachedGitHubClient;

    // Infrastructure — new KV namespaces
    scoresKvCache: CacheService;
    developersKvCache: CacheService;
    attendanceKvCache: CacheService;

    // Infrastructure — D1
    d1Service: D1Service;

    // Repos
    reposService: ReposService;

    // Metrics
    prFetcherService: PrFetcherService;

    // Event-Driven Scoring
    eventsService: EventsService;
    pointsRulesService: PointsRulesService;
    scoreAggregationService: ScoreAggregationService;
    attendanceService: AttendanceService;



    // Google Meet
    googleMeetClient: GoogleMeetClient;
    workspaceEventsClient: WorkspaceEventsClient;
    meetingsService: MeetingsService;
    meetEventsService: MeetEventsService;

    // Logs
    logsService: LogsService;
}
