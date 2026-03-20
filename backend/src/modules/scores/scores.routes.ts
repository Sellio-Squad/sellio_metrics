/**
 * Scores / Leaderboard Routes
 * GET /api/scores/leaderboard
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { isBot } from "../../lib/bot-filter";
import type { LeaderboardPeriod } from "./score-aggregation.service";

const VALID_PERIODS = new Set<string>(["all", "month", "week"]);

const scores = new Hono<HonoEnv>();

scores.get("/leaderboard", safe(async (c) => {
    const { scoreAggregationService, cachedGithubClient, developerRepo, env } = useCradle(c);

    const periodParam = c.req.query("period") ?? "";
    const period: LeaderboardPeriod = VALID_PERIODS.has(periodParam)
        ? (periodParam as LeaderboardPeriod)
        : "all";
    const limit = parseInt(c.req.query("limit") || "50", 10);

    const result = await scoreAggregationService.getLeaderboard(period, limit);

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
