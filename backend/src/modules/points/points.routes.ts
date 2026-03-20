/**
 * Points Rules Routes
 * GET /api/points/rules
 * PUT /api/points/rules
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

interface UpdateRuleBody {
    eventType: string;
    points:    number;
    description?: string;
}

const points = new Hono<HonoEnv>();

points.get("/rules", safe(async (c) => {
    const rules = await useCradle(c).pointsRulesService.getRules();
    return c.json({ rules });
}));

points.put("/rules", safe(async (c) => {
    const body = await c.req.json<UpdateRuleBody>();

    if (!body.eventType || typeof body.points !== "number") {
        return c.json({ error: "Body must contain 'eventType' (string) and 'points' (number)" }, 400);
    }

    const rule = await useCradle(c).pointsRulesService.updateRule(
        body.eventType, body.points, body.description,
    );
    return c.json({ ok: true, rule });
}));

export default points;
