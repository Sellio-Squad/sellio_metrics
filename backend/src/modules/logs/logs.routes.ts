/**
 * Logs Routes
 * GET /api/logs
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const logs = new Hono<HonoEnv>();

logs.get("/", safe(async (c) => {
    const limit = parseInt(c.req.query("limit") || "50", 10);
    return c.json(await useCradle(c).logsService.getLogs(limit));
}));

logs.delete("/", safe(async (c) => {
    await useCradle(c).logsService.clearLogs();
    return c.json({ success: true, message: "Logs cleared successfully" });
}));

export default logs;
