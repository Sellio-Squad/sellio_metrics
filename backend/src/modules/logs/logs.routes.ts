/**
 * Logs Routes
 * GET    /api/logs          — Retrieve recent system event log entries
 * GET    /api/logs/quota    — Show KV write usage for today (debug/monitoring)
 * DELETE /api/logs          — Clear the log feed
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const logs = new Hono<HonoEnv>();

logs.get("/", safe(async (c) => {
    const limit = parseInt(c.req.query("limit") || "50", 10);
    return c.json(await useCradle(c).logsService.getLogs(limit));
}));

/**
 * GET /api/logs/quota
 * Returns today's KV write count so the dashboard can show quota usage.
 * Free tier limit: 1,000 writes/day.
 */
logs.get("/quota", safe(async (c) => {
    const stats = await useCradle(c).logsService.getQuotaStats();
    return c.json({
        ...stats,
        freeLimit:        1_000,
        percentUsed:      Math.round((stats.writesTotal / 1_000) * 100),
        remainingWrites:  Math.max(0, 1_000 - stats.writesTotal),
    });
}));

logs.delete("/", safe(async (c) => {
    await useCradle(c).logsService.clearLogs();
    return c.json({ success: true, message: "Logs cleared successfully" });
}));

export default logs;
