/**
 * Sellio Metrics — Cache Registry
 *
 * A single named-namespace facade injected into every service.
 * Instead of 4 separately-named CacheService instances scattered
 * across the DI container, services receive one `CacheRegistry`
 * and access the right namespace by name:
 *
 *   cache.general.get("github:repos:org")
 *   cache.scores.set("leaderboard:all", result, TTL)
 *   cache.members.del("github:org-members:org")
 *   cache.attendance.get("session:devId")
 *
 * Benefits:
 *  - Zero code repetition: one constructor param instead of 4
 *  - Central logging & metrics point for all cache operations
 *  - Easy to swap storage backend (e.g. Redis) in one place
 *  - Namespace semantics explicit and self-documenting
 */

import { CacheService } from "./cache.service";
import type { KVNamespace } from "./cache.service";
import type { Logger } from "../../core/logger";

export interface CacheRegistryOptions {
    generalKv:    KVNamespace | null;
    scoresKv:     KVNamespace | null;
    membersKv:    KVNamespace | null;
    attendanceKv: KVNamespace | null;
    logger:       Logger;
}

export class CacheRegistry {
    /** General-purpose cache (GitHub repos, open PRs, user profiles, meet events) */
    readonly general:    CacheService;
    /** Dedicated namespace for leaderboard snapshots and point rules */
    readonly scores:     CacheService;
    /** Dedicated namespace for org-members list (flushed by GitHub webhook) */
    readonly members:    CacheService;
    /** Dedicated namespace for live attendance sessions */
    readonly attendance: CacheService;

    constructor({ generalKv, scoresKv, membersKv, attendanceKv, logger }: CacheRegistryOptions) {
        this.general    = new CacheService({ kvNamespace: generalKv,    logger });
        this.scores     = new CacheService({ kvNamespace: scoresKv,     logger });
        this.members    = new CacheService({ kvNamespace: membersKv,    logger });
        this.attendance = new CacheService({ kvNamespace: attendanceKv, logger });
    }
}
