/**
 * Open Issues Routes
 * GET /api/issues
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const issues = new Hono<HonoEnv>();

issues.get("/", safe(async (c) => {
    const { openIssuesService, env } = useCradle(c);
    const data = await openIssuesService.fetchOpenIssues(env.org);
    return c.json({ data });
}));

export default issues;
