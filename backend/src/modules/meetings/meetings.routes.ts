import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import type { MeetingsService } from "./meetings.service";
import type { WebhookHandlerService } from "./webhook-handler.service";

// Narrow local interface — avoids generics conflict with @cloudflare/workers-types
export interface CFDurableObjectNamespace {
    idFromName(name: string): { toString(): string };
    get(id: { toString(): string }): { fetch(req: Request): Promise<Response> };
}

export function meetingsRoutes(
    meetingsService: MeetingsService,
    webhookHandler: WebhookHandlerService,
    meetingRooms: CFDurableObjectNamespace,
) {
    const app = new Hono<HonoEnv>();

    // ─── OAuth ───────────────────────────────────────────────────────────────

    app.get("/auth-url", async (c) => {
        const url = meetingsService.getAuthUrl();
        return c.json({ url });
    });

    app.get("/auth-status", async (c) => {
        const authenticated = await meetingsService.isReady();
        return c.json({ authenticated });
    });

    app.get("/oauth2callback", async (c) => {
        const code = c.req.query("code");
        if (!code) return c.json({ error: "Missing authorization code" }, 400);
        await meetingsService.authorize(code);
        return c.text("Authentication successful — you can close this tab.");
    });

    app.post("/auth-logout", async (c) => {
        await meetingsService.clearCredentials();
        return c.json({ success: true });
    });

    // ─── Meeting CRUD ─────────────────────────────────────────────────────────

    app.post("/", async (c) => {
        const isReady = await meetingsService.isReady();
        if (!isReady) {
            const authUrl = meetingsService.getAuthUrl();
            return c.json({ error: "Not authenticated", requiresAuth: true, authUrl }, 401);
        }
        const body = await c.req.json<{ title?: string }>();
        const title = body?.title?.trim();
        if (!title) return c.json({ error: "title is required" }, 400);
        const meeting = await meetingsService.createMeeting(title);
        return c.json(meeting, 201);
    });

    app.get("/", async (c) => {
        const meetings = await meetingsService.listMeetings();
        return c.json(meetings);
    });

    app.get("/:id", async (c) => {
        const meeting = await meetingsService.getMeeting(c.req.param("id"));
        return c.json(meeting);
    });

    app.get("/:id/participants", async (c) => {
        const participants = await meetingsService.getActiveParticipants(c.req.param("id"));
        return c.json(participants);
    });

    app.post("/:id/end", async (c) => {
        await meetingsService.endMeeting(c.req.param("id"));
        return c.json({ success: true });
    });

    // ─── Pub/Sub Webhook ─────────────────────────────────────────────────────
    // Google Workspace Events pushes CloudEvents here via Pub/Sub.
    // WebhookHandlerService verifies the JWT, decodes the payload,
    // and forwards to the correct MeetingRoom Durable Object.

    app.post("/events/webhook", async (c) => {
        const { meetingsRepo } = c.get("cradle");
        return webhookHandler.handle(c.req.raw, meetingsRepo, meetingRooms as any);
    });

    // ─── WebSocket (real-time participant updates) ────────────────────────────
    // Flutter connects to this endpoint to receive participant_joined /
    // participant_left / meeting_ended events in real-time.

    app.get("/:id/ws", (c) => {
        const id     = c.req.param("id");
        const doId   = meetingRooms.idFromName(id);
        const doStub = meetingRooms.get(doId);
        return doStub.fetch(c.req.raw);
    });

    return app;
}
