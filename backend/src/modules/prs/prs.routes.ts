/**
 * Open PRs Routes
 * GET /api/prs
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const prs = new Hono<HonoEnv>();

prs.get("/", safe(async (c) => {
    const { openPrsService, env } = useCradle(c);
    const data = await openPrsService.fetchOpenPrs(env.org);
    return c.json({ data });
}));

export default prs;
