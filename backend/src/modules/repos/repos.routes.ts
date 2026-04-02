/**
 * Repos Routes
 * GET /api/repos         — GitHub org repos (discovery)
 * GET /api/repos/synced  — D1 repos with integer IDs (for leaderboard filtering)
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

/** GitHub-sourced repo list (used for discovery / sync selection) */
repos.get("/", zValidator("query", reposQuerySchema), safe(async (c) => {
    const { reposService, env } = useCradle(c);
    const { org: queryOrg } = c.req.valid("query") as ReposQuery;
    const org = queryOrg || env.org;
    const reposList = await reposService.listByOrg(org);
    return c.json({ org, count: reposList.length, repos: reposList });
}));

/** D1-sourced synced repo list — includes integer `id` for leaderboard filtering */
repos.get("/synced", safe(async (c) => {
    const { reposRepo } = useCradle(c);
    const reposList = await reposRepo.listRepos();
    return c.json({ count: reposList.length, repos: reposList });
}));

export default repos;
