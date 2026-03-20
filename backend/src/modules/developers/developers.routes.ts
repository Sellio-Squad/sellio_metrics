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

    const { scoresRepo, scoreAggregationService } = useCradle(c);
    const deleted = await scoresRepo.deleteDeveloperData(developerId);
    await scoreAggregationService.precomputeSnapshots();

    return c.json({ ok: true, developerId, eventsDeleted: deleted.prs + deleted.comments + deleted.attendance });
}));

export default developers;
