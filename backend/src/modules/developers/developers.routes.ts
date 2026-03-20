/**
 * Developers Routes
 * DELETE /api/developers/:developerId/events
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { AppError } from "../../core/app-error";

const developers = new Hono<HonoEnv>();

developers.delete("/:developerId/events", safe(async (c) => {
    const developerId = c.req.param("developerId");
    if (!developerId) throw new AppError("Missing developerId", 400);

    const { d1Service, scoreAggregationService } = useCradle(c);
    const deleted = await d1Service.deleteEventsByDeveloper(developerId);
    await scoreAggregationService.precomputeSnapshots();

    return c.json({ ok: true, developerId, eventsDeleted: deleted });
}));

export default developers;
