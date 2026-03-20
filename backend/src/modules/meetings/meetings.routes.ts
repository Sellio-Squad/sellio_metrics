/**
 * Meetings Routes (Google Meet)
 * GET    /api/meetings/auth-url
 * GET    /api/meetings/auth-status
 * GET    /api/meetings/oauth2callback
 * POST   /api/meetings/auth-logout
 * GET    /api/meetings/rate-limit
 * GET    /api/meetings/analytics
 * GET    /api/meetings
 * POST   /api/meetings
 * GET    /api/meetings/:id
 * GET    /api/meetings/:id/attendance
 * POST   /api/meetings/:id/end
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe, oauthSuccessHtml, oauthErrorHtml, oauthFailHtml } from "../../lib/route-helpers";

interface CreateMeetingBody { title: string; }

const meetings = new Hono<HonoEnv>();

meetings.get("/auth-url", (c) =>
    c.json({ authUrl: useCradle(c).meetingsService.getAuthUrl() }),
);

meetings.get("/auth-status", safe(async (c) =>
    c.json({ isReady: await useCradle(c).meetingsService.isReady() }),
));

meetings.get("/oauth2callback", async (c) => {
    const { meetingsService } = useCradle(c);
    const code  = c.req.query("code");
    const error = c.req.query("error");

    if (error) return oauthErrorHtml(error,
        "Check that this Google account is added as a test user in " +
        "<a href='https://console.cloud.google.com/apis/credentials/consent' target='_blank'>" +
        "Google Cloud Console → OAuth consent screen</a>.",
    );
    if (!code) return c.json({ error: "Missing code" }, 400);

    try {
        await meetingsService.authorize(code);
        return oauthSuccessHtml();
    } catch (e: any) {
        return oauthFailHtml(e?.message || "Unknown error");
    }
});

meetings.post("/auth-logout", safe(async (c) => {
    await useCradle(c).meetingsService.clearCredentials();
    return c.json({ success: true });
}));

meetings.get("/rate-limit", (c) =>
    c.json(useCradle(c).meetingsService.getRateLimitStatus()),
);

meetings.get("/analytics", safe(async (c) =>
    c.json(await useCradle(c).meetingsService.getAnalytics()),
));

meetings.get("/", safe(async (c) =>
    c.json(await useCradle(c).meetingsService.listMeetings()),
));

meetings.post("/", safe(async (c) => {
    const { meetingsService } = useCradle(c);
    if (!(await meetingsService.isReady())) {
        return c.json(
            { error: "UNAUTHORIZED", message: "Sign in required.", authUrl: meetingsService.getAuthUrl() },
            401,
        );
    }
    const body = await c.req.json<CreateMeetingBody>();
    return c.json(await meetingsService.createMeeting(body.title));
}));

meetings.get("/:id/attendance", safe(async (c) =>
    c.json(await useCradle(c).meetingsService.getAttendance(c.req.param("id")!)),
));

meetings.get("/:id", safe(async (c) =>
    c.json(await useCradle(c).meetingsService.getMeeting(c.req.param("id")!)),
));

meetings.post("/:id/end", safe(async (c) => {
    await useCradle(c).meetingsService.endMeeting(c.req.param("id")!);
    return c.json({ success: true });
}));

export default meetings;
