/**
 * Meeting Room — Cloudflare Durable Object
 *
 * One instance per meeting (keyed by meetingId).
 * Responsibilities:
 *   1. Accept WebSocket connections from Flutter clients
 *   2. Receive webhook events forwarded by WebhookHandlerService
 *   3. Persist participant join/leave/end to D1 via MeetingsRepository
 *   4. Broadcast MeetingWSEvent to all connected WebSocket clients
 *   5. On meeting_ended: close all WS connections with code 1000
 *
 * Uses the WebSocket Hibernation API so the DO unloads from memory
 * during idle periods while keeping connections alive.
 */

import type { DurableObjectState } from "@cloudflare/workers-types";
import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/logger";
import { MeetingsRepository } from "./meetings.repository";
import type { MeetingWSEvent, ParticipantSessionRow } from "./meetings.types";
import { createConsoleLogger } from "../../core/console-logger";

interface IncomingEvent {
    sessionId: string;
    event: {
        type: string;
        spaceName: string;
        participantKey: string | null;
        displayName: string;
        timestamp: string;
    };
}

export class MeetingRoom {
    private readonly state:  DurableObjectState;
    private readonly db:     D1Database | null;
    private readonly logger: Logger;

    constructor(state: DurableObjectState, env: { DB?: D1Database }) {
        this.state  = state;
        this.db     = env.DB ?? null;
        this.logger = createConsoleLogger().child({ module: "meeting-room-do" });
    }

    // ─── Durable Object Fetch Handler ────────────────────────────────────────

    async fetch(request: Request): Promise<Response> {
        const url = new URL(request.url);

        // Path: /ws  — Flutter WebSocket upgrade
        if (url.pathname === "/ws" || request.headers.get("Upgrade") === "websocket") {
            return this.handleWebSocketUpgrade(request);
        }

        // Path: /event  — Forwarded from WebhookHandlerService
        if (url.pathname === "/event" && request.method === "POST") {
            return this.handleIncomingEvent(request);
        }

        return new Response("Not Found", { status: 404 });
    }

    // ─── WebSocket Upgrade ────────────────────────────────────────────────────

    private handleWebSocketUpgrade(_request: Request): Response {
        // Cloudflare Workers WebSocket Pair
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const pair = new (globalThis as any).WebSocketPair() as { 0: WebSocket; 1: WebSocket };
        const [client, server] = [pair[0], pair[1]];

        // Hibernation API — DO can unload between messages
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        this.state.acceptWebSocket(server as any);

        this.logger.info("WebSocket client connected");
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        return new Response(null, { status: 101, webSocket: client } as any);
    }

    // ─── WebSocket Event Handlers (Hibernation API) ───────────────────────────

    async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
        // Heartbeat / ping from client — no action needed
        try {
            const msg = JSON.parse(typeof message === "string" ? message : "{}");
            if (msg.type === "ping") ws.send(JSON.stringify({ type: "pong" }));
        } catch { /* ignore malformed messages */ }
    }

    async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
        this.logger.info({ code, reason }, "WebSocket client disconnected");
        ws.close(code, "Closing");
    }

    async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
        this.logger.warn({ error }, "WebSocket error");
        ws.close(1011, "Internal error");
    }

    // ─── Incoming Event from WebhookHandlerService ───────────────────────────

    private async handleIncomingEvent(request: Request): Promise<Response> {
        let body: IncomingEvent;
        try {
            body = await request.json() as IncomingEvent;
        } catch {
            return new Response("Bad Request", { status: 400 });
        }

        const { sessionId, event } = body;
        const repo = new MeetingsRepository(this.db, this.logger);
        const now  = event.timestamp;

        try {
            switch (event.type) {
                case "google.workspace.meet.participant.v2.joined":
                    await this.onParticipantJoined(repo, sessionId, event, now);
                    break;

                case "google.workspace.meet.participant.v2.left":
                    await this.onParticipantLeft(repo, sessionId, event, now);
                    break;

                case "google.workspace.meet.conference.v2.ended":
                    await this.onMeetingEnded(repo, sessionId, now);
                    return new Response("OK", { status: 200 }); // WS already closed
            }
        } catch (err: any) {
            this.logger.error({ err: err?.message, sessionId, type: event.type }, "Error processing event");
        }

        return new Response("OK", { status: 200 });
    }

    // ─── Participant Join ─────────────────────────────────────────────────────

    private async onParticipantJoined(
        repo: MeetingsRepository,
        sessionId: string,
        event: IncomingEvent["event"],
        now: string,
    ): Promise<void> {
        const participantKey = event.participantKey ?? event.displayName;

        const row: ParticipantSessionRow = {
            id:             `${sessionId}:${participantKey}:${Date.parse(now)}`,
            sessionId,
            participantKey,
            displayName:    event.displayName,
            startTime:      now,
            endTime:        null,
        };

        await repo.insertParticipantJoin(row);

        this.broadcast({
            type:        "participant_joined",
            meetingId:   sessionId,
            participant: { participantKey, displayName: event.displayName },
            timestamp:   now,
        });

        this.logger.info({ sessionId, participantKey }, "Participant joined");
    }

    // ─── Participant Left ─────────────────────────────────────────────────────

    private async onParticipantLeft(
        repo: MeetingsRepository,
        sessionId: string,
        event: IncomingEvent["event"],
        now: string,
    ): Promise<void> {
        const participantKey = event.participantKey ?? event.displayName;

        await repo.markParticipantLeft(sessionId, participantKey, now);

        this.broadcast({
            type:        "participant_left",
            meetingId:   sessionId,
            participant: { participantKey, displayName: event.displayName },
            timestamp:   now,
        });

        this.logger.info({ sessionId, participantKey }, "Participant left");
    }

    // ─── Meeting Ended ────────────────────────────────────────────────────────

    private async onMeetingEnded(
        repo: MeetingsRepository,
        sessionId: string,
        now: string,
    ): Promise<void> {
        // 1. Close all open participant sessions
        await repo.closeAllParticipantSessions(sessionId, now);

        // 2. Broadcast meeting_ended to all connected Flutter clients
        this.broadcast({ type: "meeting_ended", meetingId: sessionId, timestamp: now });

        // 3. Close all WebSocket connections with code 1000 (Normal Closure)
        const connections = this.state.getWebSockets();
        for (const ws of connections) {
            try {
                ws.close(1000, "Meeting ended");
            } catch { /* already closed */ }
        }

        this.logger.info({ sessionId }, "Meeting ended — all WebSocket connections closed");
    }

    // ─── Broadcast ───────────────────────────────────────────────────────────

    private broadcast(event: MeetingWSEvent): void {
        const payload = JSON.stringify(event);
        const connections = this.state.getWebSockets();

        for (const ws of connections) {
            try {
                ws.send(payload);
            } catch { /* stale connection, ignore */ }
        }

        this.logger.info({ type: event.type, connectionCount: connections.length }, "Broadcast sent");
    }
}
