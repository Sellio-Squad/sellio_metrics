/**
 * Health & Ping Routes
 * GET /api/ping
 * GET /api/health
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle } from "../../lib/route-helpers";

const health = new Hono<HonoEnv>();

health.get("/ping", (c) => c.json({ pong: true, time: new Date().toISOString() }));

health.get("/health", (c) => {
    const { env, rateLimitGuard, d1Service } = useCradle(c);
    return c.json({
        status:          "ok",
        org:             env.org,
        timestamp:       new Date().toISOString(),
        githubRateLimit: rateLimitGuard.getStatus(),
        d1Available:     d1Service.isAvailable,
    });
});

export default health;
