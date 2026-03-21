/**
 * GitHub Sync Routes
 * POST   /api/sync/github         — Sync merged PRs for one or more repos
 * POST   /api/sync/github/members — Sync org member profiles (display names, joined_at)
 * DELETE /api/sync/github/reset   — Wipe all sync data and caches for a clean re-sync
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { syncOneRepo, syncOrgMembers } from "./sync.service";

import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const syncSchema = z.object({
    owner:     z.string().optional(),
    repo:      z.string().optional(),
    repos:     z.array(z.string()).optional(),
    prNumbers: z.array(z.number()).optional(),
    /**
     * force=true fetches all pages (20) regardless of what's in DB.
     * Use when you want a full historical re-sync.
     */
    force:     z.boolean().optional().default(false),
}).refine(data => data.repo || (data.repos && data.repos.length > 0), {
    message: "Body must contain 'repo' (string) or 'repos' (string[]). Example: { \"repos\": [\"sellio_mobile\"] }",
    path: ["repo", "repos"],
});

type SyncBody = z.infer<typeof syncSchema>;

const sync = new Hono<HonoEnv>();

// ─── Sync PRs ────────────────────────────────────────────────
sync.post("/github", zValidator("json", syncSchema), safe(async (c) => {
    const cradle = useCradle(c);
    const body   = c.req.valid("json") as SyncBody;
    const owner  = body.owner || cradle.env.org;
    const force  = body.force ?? false;

    const repoNames: string[] =
        Array.isArray(body.repos) && body.repos.length > 0 ? body.repos :
        typeof body.repo === "string" && body.repo        ? [body.repo] :
        [];

    const orgRepos = await cradle.cachedGithubClient.listOrgRepos(owner);
    const results: any[] = [];
    let anyError = false;

    for (const repoName of repoNames) {
        try {
            results.push(await syncOneRepo(cradle, owner, repoName, orgRepos, body.prNumbers, force));
        } catch (e: any) {
            cradle.logger.error({ repo: repoName, err: e.message }, "Repo sync failed");
            results.push({ ok: false, repo: `${owner}/${repoName}`, error: e.message });
            anyError = true;
        }
    }

    await cradle.scoreAggregationService.precomputeSnapshots();

    return repoNames.length === 1
        ? c.json(results[0])
        : c.json({ ok: !anyError, syncedRepos: results });
}));

// ─── Sync Org Members ─────────────────────────────────────────
sync.post("/github/members", safe(async (c) => {
    const cradle = useCradle(c);
    const org    = cradle.env.org;
    const result = await syncOrgMembers(cradle, org);
    return c.json({ ok: true, org, ...result });
}));

// ─── Reset All Sync Data ──────────────────────────────────────
/**
 * Wipes merged_prs, pr_comments, developers, and repositories tables, 
 * then busts all relevant KV caches for a completely fresh start.
 * After calling this, run a fresh sync to repopulate everything.
 */
sync.delete("/github/reset", safe(async (c) => {
    const cradle = useCradle(c);
    const { d1Service, cacheService, scoresKvCache, logger, env } = cradle;

    logger.info("Starting full database reset");

    const { prsDeleted, commentsDeleted, devsDeleted, reposDeleted } = await d1Service.truncateSyncData();

    logger.info({ prsDeleted, commentsDeleted, devsDeleted, reposDeleted }, "Sync tables cleared");

    // Bust all relevant caches
    const org = env.org;
    await Promise.allSettled([
        cacheService.del(`sellio:leaderboard:all`),
        scoresKvCache.del(`sellio:leaderboard:all`),
        cacheService.del(`github:open_prs:${org}`),
        cacheService.del(`github:repos:${org}`),
        cacheService.del(`github:org-members:${org}`),
    ]);

    logger.info("All KV caches cleared");

    return c.json({
        ok: true,
        message: "All sync data wiped. Run a fresh sync to repopulate.",
        cleared: { prsDeleted, commentsDeleted, devsDeleted, reposDeleted },
    });
}));

export default sync;
