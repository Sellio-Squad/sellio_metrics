/**
 * Open Tickets Routes
 * GET /api/tickets          — returns merged open tickets
 * GET /api/tickets?nocache  — bypasses KV cache (debug)
 * GET /api/tickets?debug    — returns raw diagnostic info
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { GitHubGraphQLClient } from "../../infra/github/github-graphql.client";

const tickets = new Hono<HonoEnv>();

tickets.get("/", safe(async (c) => {
    const { openTicketsService, cachedGithubClient, cacheService, env, logger } = useCradle(c);
    const org = env.org;
    const nocache = c.req.query("nocache") !== undefined;

    // ── Cache bypass ──────────────────────────────────────────
    if (nocache) {
        const cacheKey = `github:open_tickets:${org}`;
        await cacheService.del(cacheKey);
        logger.info({ org }, "[tickets] Cache cleared by ?nocache");
    }

    // ── Normal fetch ──────────────────────────────────────────
    const data = await openTicketsService.fetchOpenTickets(org);
    return c.json({ data });
}));

export default tickets;
