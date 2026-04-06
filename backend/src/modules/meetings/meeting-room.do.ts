/**
 * Meeting Room — Cloudflare Durable Object (Thin Shell)
 *
 * One instance per meeting (keyed by meetingId).
 *
 * This class is the ONLY file with Cloudflare-specific code.
 * All business logic is delegated to MeetingEventHandler,
 * and all connection management to CloudflareConnectionManager.
 *
 * To migrate to Node.js / `ws` / Socket.IO:
 *   1. Swap CloudflareConnectionManager for a WsConnectionManager
 *   2. Replace this DO shell with a standard WebSocket server
 *   3. MeetingEventHandler stays unchanged
 *
 * Uses the WebSocket Hibernation API so the DO unloads from memory
 * during idle periods while keeping connections alive.
 */

import type { DurableObjectState } from "@cloudflare/workers-types";
import type { D1Database } from "../../infra/database/d1.service";
import type { Logger } from "../../core/logger";
import { MeetingsRepository } from "./meetings.repository";
import { createConsoleLogger } from "../../core/logger";
import { LogsService } from "../logs/logs.service";
import { CacheService } from "../../infra/cache/cache.service";
import { CloudflareConnectionManager } from "./websocket/cloudflare-connection-manager";
import { MeetingEventHandler, type IncomingMeetEvent } from "./websocket/meeting-event-handler";

export class MeetingRoom {
    private readonly state:  DurableObjectState;
    private readonly logger: Logger;
    private readonly connectionManager: CloudflareConnectionManager;
    private readonly eventHandler: MeetingEventHandler;

    constructor(state: DurableObjectState, env: any) {
        this.state  = state;
        this.logger = createConsoleLogger().child({ module: "meeting-room-do" });

        // ── Build dependencies ──────────────────────────────────────────────
        const db: D1Database | null = env.DB ?? null;

        let logsService: LogsService | null = null;
        if (env.CACHE) {
            const cache = new CacheService({ kvNamespace: env.CACHE, logger: this.logger });
            logsService = new LogsService({ cacheService: cache, logger: this.logger });
        }

        // ── Platform-specific: connection manager ───────────────────────────
        this.connectionManager = new CloudflareConnectionManager(state, this.logger);

        // ── Platform-agnostic: business logic ───────────────────────────────
        const repo = new MeetingsRepository(db, this.logger);
        this.eventHandler = new MeetingEventHandler(
            this.connectionManager,
            repo,
            this.logger,
            logsService,
        );
    }

    // ─── Durable Object Fetch Handler ────────────────────────────────────────

    async fetch(request: Request): Promise<Response> {
        const url = new URL(request.url);

        // Path: /ws  — Flutter WebSocket upgrade
        if (url.pathname === "/ws" || request.headers.get("Upgrade") === "websocket") {
            return this.connectionManager.acceptUpgrade(request);
        }

        // Path: /event  — Forwarded from WebhookHandlerService
        if (url.pathname === "/event" && request.method === "POST") {
            return this.handleIncomingEvent(request);
        }

        return new Response("Not Found", { status: 404 });
    }

    // ─── WebSocket Event Handlers (Hibernation API) ───────────────────────────

    async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
        // With setWebSocketAutoResponse, ping/pong is handled automatically.
        // This handler only fires for non-auto-response messages.
        try {
            const msg = JSON.parse(typeof message === "string" ? message : "{}");
            // Manual ping fallback (for clients that send plain "ping" text)
            if (msg.type === "ping") ws.send(JSON.stringify({ type: "pong" }));
        } catch (err: any) {
            this.logger.debug({ err: err?.message }, "Malformed WebSocket message received");
        }
    }

    async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
        this.logger.info({ code, reason }, "WebSocket client disconnected");
        try {
            ws.close(code, "Closing");
        } catch (err: any) {
            this.logger.debug({ err: err?.message }, "Error during WebSocket close handshake");
        }
    }

    async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
        this.logger.warn({ error }, "WebSocket error");
        try {
            ws.close(1011, "Internal error");
        } catch (err: any) {
            this.logger.debug({ err: err?.message }, "Error closing errored WebSocket");
        }
    }

    // ─── Incoming Event from WebhookHandlerService ───────────────────────────

    private async handleIncomingEvent(request: Request): Promise<Response> {
        let body: IncomingMeetEvent;
        try {
            body = await request.json() as IncomingMeetEvent;
        } catch {
            return new Response("Bad Request", { status: 400 });
        }

        await this.eventHandler.handleEvent(body);

        return new Response("OK", { status: 200 });
    }
}
