/**
 * GitHub Sync Routes
 * POST /api/sync/github
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { syncOneRepo } from "./sync.service";

interface SyncBody {
    owner?: string;
    repo?:  string;
    repos?: string[];
    prNumbers?: number[];
}

const sync = new Hono<HonoEnv>();

sync.post("/github", safe(async (c) => {
    const cradle = useCradle(c);
    const body   = await c.req.json<SyncBody>().catch(() => ({} as SyncBody));
    const owner  = body.owner || cradle.env.org;

    const repoNames: string[] =
        Array.isArray(body.repos) && body.repos.length > 0 ? body.repos :
        typeof body.repo === "string" && body.repo        ? [body.repo] :
        [];

    if (repoNames.length === 0) {
        return c.json(
            { error: "Body must contain 'repo' (string) or 'repos' (string[]). Example: { \"repos\": [\"sellio_mobile\"] }" },
            400,
        );
    }

    const orgRepos = await cradle.cachedGithubClient.listOrgRepos(owner);
    const results: any[] = [];
    let anyError = false;

    for (const repoName of repoNames) {
        try {
            results.push(await syncOneRepo(cradle, owner, repoName, orgRepos, body.prNumbers));
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

export default sync;
