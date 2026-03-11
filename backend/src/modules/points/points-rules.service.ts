/**
 * Points Rules Module — Service
 *
 * Reads from SCORES_KV (fast), falls back to D1.
 * Updates write to both D1 and KV (no TTL).
 * Logs every rule change for audit/debugging.
 */

import type { D1Service } from "../../infra/database/d1.service";
import type { CacheService } from "../../infra/cache/cache.service";
import type { Logger } from "../../core/logger";
import type { PointRule, RuleChangeLogEntry } from "../../core/event-types";

const RULES_KV_KEY = "point_rules:all";
const RULE_CHANGE_LOG_KEY = "rule_change_log";

export class PointsRulesService {
    private readonly d1: D1Service;
    private readonly scoresKv: CacheService;
    private readonly logger: Logger;

    constructor({
        d1Service,
        scoresKvCache,
        logger,
    }: {
        d1Service: D1Service;
        scoresKvCache: CacheService;
        logger: Logger;
    }) {
        this.d1 = d1Service;
        this.scoresKv = scoresKvCache;
        this.logger = logger.child({ module: "points-rules" });
    }

    /**
     * Get all point rules. Reads from KV first (fast), falls back to D1.
     */
    async getRules(): Promise<PointRule[]> {
        // Try KV first (zero latency)
        const cached = await this.scoresKv.get<PointRule[]>(RULES_KV_KEY);
        if (cached?.data) {
            return cached.data;
        }

        // Fall back to D1
        const rules = await this.d1.getPointRules();

        // Sync to KV for next time (no TTL — permanent)
        if (rules.length > 0) {
            await this.scoresKv.set(RULES_KV_KEY, rules);
        }

        return rules;
    }

    /**
     * Update a point rule. Writes to D1, syncs to KV, logs the change,
     * and invalidates all cached scores (since rules affect everyone).
     */
    async updateRule(eventType: string, points: number, description?: string): Promise<PointRule> {
        // Get old value for audit log
        const oldRules = await this.getRules();
        const oldRule = oldRules.find((r) => r.eventType === eventType);
        const oldPoints = oldRule?.points ?? 0;

        // Write to D1
        await this.d1.setPointRule(eventType, points, description);

        // Log the change
        await this.logRuleChange({
            eventType,
            oldPoints,
            newPoints: points,
            changedAt: new Date().toISOString(),
        });

        // Re-sync all rules to KV
        const updatedRules = await this.d1.getPointRules();
        await this.scoresKv.set(RULES_KV_KEY, updatedRules);

        // Invalidate ALL cached scores (rules affect everyone)
        await this.invalidateAllScores();

        this.logger.info(
            { eventType, oldPoints, newPoints: points },
            "Point rule updated, all scores invalidated",
        );

        return updatedRules.find((r) => r.eventType === eventType)!;
    }

    // ─── Private ────────────────────────────────────────────

    private async logRuleChange(entry: RuleChangeLogEntry): Promise<void> {
        try {
            const cached = await this.scoresKv.get<RuleChangeLogEntry[]>(RULE_CHANGE_LOG_KEY);
            const log = cached?.data || [];
            log.unshift(entry);
            // Keep last 100 changes
            if (log.length > 100) log.length = 100;
            await this.scoresKv.set(RULE_CHANGE_LOG_KEY, log);
        } catch (err: any) {
            this.logger.warn({ err: err.message }, "Failed to log rule change");
        }
    }

    private async invalidateAllScores(): Promise<void> {
        try {
            await this.scoresKv.del("leaderboard:all");
            // Note: per-developer caches will expire naturally or be
            // recomputed on next access with the new rules
        } catch (err: any) {
            this.logger.warn({ err: err.message }, "Failed to invalidate score caches");
        }
    }
}
