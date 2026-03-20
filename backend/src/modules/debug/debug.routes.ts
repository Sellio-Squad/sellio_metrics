/**
 * Debug Routes — Lazily loaded (rarely used in production)
 * GET /api/debug/auth
 * GET /api/debug/meet-subscribe
 * GET /api/debug/cache-quota
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

const debug = new Hono<HonoEnv>();

debug.get("/auth", safe(async (c) => {
    const cradle   = useCradle(c);
    const { env }  = cradle;
    const kvToken  = await cradle.cacheService.get<any>("google_oauth_tokens");
    const isReady  = await cradle.meetingsService.isReady();

    return c.json({
        hasClientId:          !!env.googleClientId && env.googleClientId.length > 10,
        hasClientSecret:      !!env.googleClientSecret && env.googleClientSecret.length > 10,
        clientIdPrefix:       env.googleClientId ? env.googleClientId.substring(0, 20) + "…" : "MISSING",
        redirectUri:          env.googleRedirectUri,
        kvIsBound:            !!cradle.kvNamespace,
        kvHasToken:           !!kvToken,
        tokenHasAccessToken:  !!(kvToken?.data?.access_token),
        tokenHasRefreshToken: !!(kvToken?.data?.refresh_token),
        tokenCachedAt:        kvToken?.cachedAt ?? null,
        tokenExpiryDate:      kvToken?.data?.expiry_date ?? null,
        isReady,
        pubsubTopic:          env.googlePubsubTopic || "NOT_SET",
    });
}));

debug.get("/meet-subscribe", safe(async (c) => {
    const cradle    = useCradle(c);
    const kvToken   = await cradle.cacheService.get<any>("google_oauth_tokens");
    const isReady   = await cradle.meetingsService.isReady();
    const spaceName = c.req.query("spaceName") || "spaces/ONkdRwFFaFMB";
    let subscribeResult: any = null;
    let subscribeError: string | null = null;

    if (isReady && cradle.env.googlePubsubTopic) {
        subscribeResult = await cradle.meetEventsService.subscribe(spaceName);
    } else {
        subscribeError = !isReady
            ? "NOT_READY: OAuth token missing. Please re-authenticate."
            : "No GOOGLE_PUBSUB_TOPIC configured.";
    }

    return c.json({
        tokenInfo: {
            exists:            !!kvToken,
            hasAccessToken:    !!(kvToken?.data?.access_token),
            hasRefreshToken:   !!(kvToken?.data?.refresh_token),
            accessTokenPrefix: kvToken?.data?.access_token
                ? kvToken.data.access_token.substring(0, 20) + "…" : null,
            expiry_date:  kvToken?.data?.expiry_date ?? null,
            cachedAt:     kvToken?.cachedAt ?? null,
        },
        isReady,
        pubsubTopic:    cradle.env.googlePubsubTopic || "NOT_SET",
        spaceName,
        subscribeResult,
        subscribeError,
    });
}));

debug.get("/cache-quota", safe(async (c) => {
    const cradle   = useCradle(c);
    const now      = new Date();
    const midnight = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));

    const [repos, orgMembers, token] = await Promise.all([
        cradle.cacheService.get<any>(`github:repos:${cradle.env.org}`),
        cradle.membersKvCache.get<any>(`github:org-members:${cradle.env.org}`),
        cradle.cacheService.get<any>("google_oauth_tokens"),
    ]);

    return c.json({
        kvFreeWriteLimit:    1000,
        kvResetAtUtc:        midnight.toISOString(),
        kvSecondsToReset:    Math.floor((midnight.getTime() - now.getTime()) / 1000),
        strategy:            "Only computed results cached (leaderboard + members + metrics). No per-PR writes.",
        d1Available:         cradle.d1Service.isAvailable,
        cachedResults: {
            [`github:repos:${cradle.env.org}`]:       { hit: !!repos },
            [`github:org-members:${cradle.env.org}`]: { hit: !!orgMembers },
            "google_oauth_tokens":                    { hit: !!token },
        },
    });
}));

export default debug;
