/**
 * Meet Events Routes (Google Workspace Events / Pub/Sub)
 * POST /api/meet-events/webhook
 * POST /api/meet-events/subscribe
 * GET  /api/meet-events/events
 * GET  /api/meet-events/subscriptions
 * DELETE /api/meet-events/subscriptions/:id
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { AppError } from "../../core/app-error";

interface SubscribeBody { spaceName: string; }

const meetEvents = new Hono<HonoEnv>();

meetEvents.post("/webhook", safe(async (c) => {
    const body  = await c.req.json<any>();
    const event = await useCradle(c).meetEventsService.handleWebhook(body);
    return c.json({ ok: true, eventId: event.id, type: event.label });
}));

meetEvents.post("/subscribe", safe(async (c) => {
    const { meetEventsService, meetingsService } = useCradle(c);

    if (!(await meetingsService.isReady())) {
        return c.json(
            { error: "UNAUTHORIZED", message: "Google OAuth sign-in required.", authUrl: meetingsService.getAuthUrl() },
            401,
        );
    }

    const body = await c.req.json<SubscribeBody>();
    if (!body.spaceName) throw new AppError("Body must contain 'spaceName'", 400);

    return c.json(await meetEventsService.subscribe(body.spaceName));
}));

meetEvents.get("/events", safe(async (c) => {
    const limit  = parseInt(c.req.query("limit") || "50", 10);
    const events = await useCradle(c).meetEventsService.listEvents(limit);
    return c.json({ count: events.length, events });
}));

meetEvents.get("/subscriptions", safe(async (c) => {
    const subscriptions = await useCradle(c).meetEventsService.listSubscriptions();
    return c.json({ count: subscriptions.length, subscriptions });
}));

meetEvents.delete("/subscriptions/:id", safe(async (c) => {
    await useCradle(c).meetEventsService.deleteSubscription(c.req.param("id")!);
    return c.json({ ok: true });
}));

export default meetEvents;
