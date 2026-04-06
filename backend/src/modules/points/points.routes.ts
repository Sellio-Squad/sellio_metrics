/**
 * Points Rules Routes
 * GET /api/points/rules
 * PUT /api/points/rules
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { AppError } from "../../core/errors";

import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const updateRuleSchema = z.object({
    eventType: z.string(),
    points:    z.number(),
    description: z.string().optional(),
});
type UpdateRuleBody = z.infer<typeof updateRuleSchema>;

const points = new Hono<HonoEnv>();

points.get("/rules", safe(async (c) => {
    const rules = await useCradle(c).pointsRulesService.getRules();
    return c.json({ rules });
}));

points.put("/rules", zValidator("json", updateRuleSchema), safe(async (c) => {
    const body = c.req.valid("json") as UpdateRuleBody;

    const rule = await useCradle(c).pointsRulesService.updateRule(
        body.eventType, body.points, body.description,
    );
    return c.json({ ok: true, rule });
}));

export default points;
