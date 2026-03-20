/**
 * Members Routes
 * GET /api/members
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { isBot } from "../../lib/bot-filter";

const members = new Hono<HonoEnv>();

members.get("/", safe(async (c) => {
    const { cachedGithubClient, d1RelationalService, env } = useCradle(c);

    const [orgMembers, dbMembers, activityMap] = await Promise.all([
        cachedGithubClient.listOrgMembers(env.org),
        d1RelationalService.getMembers(),
        d1RelationalService.getLastActiveDates(),
    ]);

    const displayNameMap = new Map(dbMembers.map((m) => [m.login, m.displayName]));
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;

    const data = (orgMembers as Array<{ login: string; type: string; avatar_url: string }>)
        .filter((m) => !isBot(m.login, m.type))
        .map((m) => {
            const activityKey = Object.keys(activityMap).find(
                (k) => k.toLowerCase() === m.login.toLowerCase(),
            );
            const lastActiveDate = activityKey ? activityMap[activityKey] : null;
            const isActive = !!lastActiveDate && new Date(lastActiveDate).getTime() >= thirtyDaysAgo;
            return {
                developer: m.login,
                displayName: displayNameMap.get(m.login) ?? null,
                avatarUrl: m.avatar_url,
                isActive,
                lastActiveDate,
            };
        })
        .sort((a, b) => {
            if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
            if (a.isActive && a.lastActiveDate && b.lastActiveDate) {
                return new Date(b.lastActiveDate).getTime() - new Date(a.lastActiveDate).getTime();
            }
            return a.developer.localeCompare(b.developer);
        });

    return c.json({ data, members: data });
}));

export default members;
