/**
 * Scores / Leaderboard Routes
 * GET /api/scores/leaderboard
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { isBot } from "../../lib/bot-filter";

import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const leaderboardQuerySchema = z.object({
    limit:  z.coerce.number().int().min(1).default(50),
    since:  z.string().optional(),   // ISO-8601 date string, e.g. "2024-01-01T00:00:00.000Z"
    until:  z.string().optional(),   // ISO-8601 date string
    repos:  z.string().optional(),   // comma-separated repo names, e.g. "sellio_mobile,sellio_backend"
});
type LeaderboardQuery = z.infer<typeof leaderboardQuerySchema>;

const scores = new Hono<HonoEnv>();

scores.get("/leaderboard", zValidator("query", leaderboardQuerySchema), safe(async (c) => {
    const { scoreAggregationService, cachedGithubClient, developerRepo, env } = useCradle(c);

    const { limit, since, until, repos: reposParam } = c.req.valid("query") as LeaderboardQuery;
    const repoIds = reposParam
        ? reposParam.split(",").map((r) => parseInt(r.trim(), 10)).filter((n) => !isNaN(n))
        : [];

    const result = await scoreAggregationService.getLeaderboard(limit, since, until, repoIds);

    // Enrich with avatar_url and display_name — best-effort (doesn't block response on failure)
    const [orgMembers, dbMembers] = await Promise.all([
        cachedGithubClient.listOrgMembers(env.org),
        developerRepo.getDevelopers(),
    ]);

    type OrgMember = { login: string; type: string; avatar_url: string };
    const typedMembers = orgMembers as OrgMember[];

    const avatarMap      = new Map(typedMembers.map((m) => [m.login, m.avatar_url]));
    const displayNameMap = new Map(dbMembers.map((m) => [m.login, m.displayName]));
    const botLogins      = new Set(typedMembers.filter((m) => isBot(m.login, m.type)).map((m) => m.login));

    result.entries = result.entries
        .filter((e) => !isBot(e.developer_login ?? "", undefined) && !botLogins.has(e.developer_login))
        .map((e) => ({
            ...e,
            displayName: displayNameMap.get(e.developer_login) ?? e.developer_login,
            avatarUrl:   avatarMap.get(e.developer_login) || `https://github.com/${e.developer_login}.png`,
        }));

    return c.json(result);
}));

export default scores;
