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
import type { ScoresRepository } from "../modules/scores/scores.repository";
import type { DeveloperRepository } from "../modules/developers/developer.repository";
import type { AttendanceRepository } from "../modules/attendance/attendance.repository";
import type { MeetingsRepository } from "../modules/meetings/meetings.repository";
import type { RateLimitGuard } from "../infra/github/rate-limit-guard";
import type { CachedGitHubClient } from "../infra/github/cached-github.client";
import type { ReposService } from "../modules/repos/repos.service";
import type { PrFetcherService } from "../modules/metrics/pr-fetcher.service";
import type { OpenPrsService } from "../modules/prs/open-prs.service";
import type { GoogleMeetClient } from "../infra/google/google-meet.client";
import type { WorkspaceEventsClient } from "../infra/google/workspace-events.client";
import type { MeetingsService } from "../modules/meetings/meetings.service";
import type { MeetEventsService } from "../modules/meet-events/meet-events.service";
import type { LogsService } from "../modules/logs/logs.service";
import type { PointsRulesService } from "../modules/points/points-rules.service";
import type { ScoreAggregationService } from "../modules/scores/score-aggregation.service";
import type { AttendanceService } from "../modules/attendance/attendance.service";
import type { env } from "../config/env";
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
    scoresRepo: ScoresRepository;
    attendanceRepo: AttendanceRepository;
    meetingsRepo: MeetingsRepository;

    // Repos
    reposService: ReposService;

    // Metrics
    prFetcherService: PrFetcherService;

    // PRs
    openPrsService: OpenPrsService;

    // Scoring
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
