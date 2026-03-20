/**
 * Repos Routes
 * GET /api/repos
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const repos = new Hono<HonoEnv>();

repos.get("/", safe(async (c) => {
    const { reposService, env } = useCradle(c);
    const org = c.req.query("org") || env.org;
    const reposList = await reposService.listByOrg(org);
    return c.json({ org, count: reposList.length, repos: reposList });
}));

export default repos;
