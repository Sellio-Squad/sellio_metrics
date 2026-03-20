/**
 * Repos Routes
 * GET /api/repos
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const reposQuerySchema = z.object({
    org: z.string().optional(),
});
type ReposQuery = z.infer<typeof reposQuerySchema>;

const repos = new Hono<HonoEnv>();

repos.get("/", zValidator("query", reposQuerySchema), safe(async (c) => {
    const { reposService, env } = useCradle(c);
    const { org: queryOrg } = c.req.valid("query") as ReposQuery;
    const org = queryOrg || env.org;
    const reposList = await reposService.listByOrg(org);
    return c.json({ org, count: reposList.length, repos: reposList });
}));

export default repos;
