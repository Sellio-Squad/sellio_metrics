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
    const debug   = c.req.query("debug")   !== undefined;

    // ── Cache bypass ──────────────────────────────────────────
    if (nocache) {
        const cacheKey = `github:open_tickets:${org}`;
        await cacheService.del(cacheKey);
        logger.info({ org }, "[tickets] Cache cleared by ?nocache");
    }

    // ── Debug mode: run each step individually, return raw counts ─
    if (debug) {
        const log = logger.child({ module: "tickets-debug" });
        const gql = new GitHubGraphQLClient((cachedGithubClient as any).raw ?? cachedGithubClient, log);

        let issuesResult: any   = { issues: [], totalCostUsed: 0, error: null };
        let projectsResult: any = { projects: [], totalCostUsed: 0, error: null };

        try {
            const r = await gql.searchOpenIssues(org);
            issuesResult = { issues: r.issues.length, totalCostUsed: r.totalCostUsed };
        } catch (e: any) {
            issuesResult = { issues: 0, error: e.message };
        }

        try {
            const r = await gql.searchOrgProjectItems(org);
            projectsResult = { projects: r.projects.length, totalCostUsed: r.totalCostUsed };
        } catch (e: any) {
            projectsResult = { projects: 0, error: e.message };
        }

        return c.json({
            debug: true,
            org,
            issues:   issuesResult,
            projects: projectsResult,
        });
    }

    // ── Normal fetch ──────────────────────────────────────────
    const data = await openTicketsService.fetchOpenTickets(org);
    return c.json({ data });
}));

export default tickets;
