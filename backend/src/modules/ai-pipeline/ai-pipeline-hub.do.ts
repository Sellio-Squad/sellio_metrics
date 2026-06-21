/**
 * AI Pipeline Hub — Cloudflare Durable Object
 *
 * Single global instance (keyed by "global").
 * Manages WebSocket connections for the AI Agent Monitor frontend page
 * and broadcasts live pipeline events pushed from AiPipelineService.
 */

import type { DurableObjectState } from "@cloudflare/workers-types";
import type { Logger } from "../../core/logger";
import { createConsoleLogger } from "../../core/logger";
import { CloudflareConnectionManager } from "../meetings/websocket/cloudflare-connection-manager";
import type { AiRunRecord } from "./ai-pipeline.types";

export class AiPipelineHub {
    private readonly state: DurableObjectState;
    private readonly logger: Logger;
    private readonly connectionManager: CloudflareConnectionManager;
    private readonly env: any;

    constructor(state: DurableObjectState, env: any) {
        this.state = state;
        this.env = env;
        this.logger = createConsoleLogger().child({ module: "ai-pipeline-hub" });
        this.connectionManager = new CloudflareConnectionManager(state, this.logger);
    }

    async fetch(request: Request): Promise<Response> {
        const url = new URL(request.url);

        // Path: /ws — WebSocket upgrade request from Flutter
        if (url.pathname === "/ws" || request.headers.get("Upgrade") === "websocket") {
            if (request.headers.get("Upgrade") !== "websocket") {
                return new Response("Expected WebSocket upgrade", { status: 426 });
            }

            const currentCount = this.connectionManager.getConnectionCount();
            if (currentCount >= 100) {
                this.logger.warn({ currentCount }, "Connection limit reached — rejecting upgrade");
                return new Response("Too Many Connections", { status: 429 });
            }

            const pair = new (globalThis as any).WebSocketPair() as { 0: WebSocket; 1: WebSocket };
            const [client, server] = [pair[0], pair[1]];

            // Hibernation API registration
            (this.state as any).acceptWebSocket(server);

            this.logger.info({ connectionCount: currentCount + 1 }, "WebSocket client connected to AI Pipeline Hub");

            // Send initial snapshot
            try {
                const runs = await this.getRecentRuns();
                server.send(JSON.stringify({ type: "snapshot", runs }));
            } catch (err: any) {
                this.logger.error({ err: err?.message }, "Failed to send initial snapshot to client");
            }

            return new Response(null, { status: 101, webSocket: client } as any);
        }

        // Path: /event — Forwarded from AiPipelineService
        if (url.pathname === "/event" && request.method === "POST") {
            let runRecord: AiRunRecord;
            try {
                runRecord = await request.json() as AiRunRecord;
            } catch {
                return new Response("Bad Request", { status: 400 });
            }

            const payload = JSON.stringify({ type: "run_update", run: runRecord });
            const result = this.connectionManager.broadcast(payload);
            this.logger.info(
                { taskId: runRecord.taskId, sent: result.sent, failed: result.failed },
                "Broadcasted run update to clients"
            );

            return new Response("OK", { status: 200 });
        }

        // Path: /event/delete/:taskId — Broadcast run deleted event
        if (url.pathname.startsWith("/event/delete/") && request.method === "POST") {
            const taskId = url.pathname.split("/").pop();
            if (!taskId) {
                return new Response("Bad Request", { status: 400 });
            }
            const payload = JSON.stringify({ type: "run_deleted", taskId });
            const result = this.connectionManager.broadcast(payload);
            this.logger.info({ taskId, sent: result.sent, failed: result.failed }, "Broadcasted run_deleted to clients");
            return new Response("OK", { status: 200 });
        }

        // Path: /event/clear — Broadcast runs cleared event
        if (url.pathname === "/event/clear" && request.method === "POST") {
            const payload = JSON.stringify({ type: "runs_cleared" });
            const result = this.connectionManager.broadcast(payload);
            this.logger.info({ sent: result.sent, failed: result.failed }, "Broadcasted runs_cleared to clients");
            return new Response("OK", { status: 200 });
        }

        return new Response("Not Found", { status: 404 });
    }

    // ─── WebSocket Event Handlers (Hibernation API) ───────────────────────────

    async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
        try {
            const msg = JSON.parse(typeof message === "string" ? message : "{}");
            if (msg.type === "ping") {
                ws.send(JSON.stringify({ type: "pong" }));
            }
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

    // ─── KV Helper ───────────────────────────────────────────────────────────

    private async getRecentRuns(): Promise<AiRunRecord[]> {
        if (!this.env.CACHE) {
            this.logger.warn("CACHE KV binding not found in DO env");
            return [];
        }
        try {
            const indexStr = await this.env.CACHE.get("sellio:ai:runs:index");
            if (!indexStr) {
                return [];
            }
            const indexObj = JSON.parse(indexStr) as { data: string[] };
            const taskIds = indexObj?.data;
            if (!Array.isArray(taskIds) || taskIds.length === 0) {
                return [];
            }

            const records = await Promise.all(
                taskIds.map(async (taskId) => {
                    const recordStr = await this.env.CACHE.get(`sellio:ai:runs:${taskId}`);
                    if (!recordStr) return null;
                    try {
                        const recordObj = JSON.parse(recordStr) as { data: AiRunRecord };
                        return recordObj?.data || null;
                    } catch {
                        return null;
                    }
                })
            );

            return records
                .filter((r): r is AiRunRecord => r !== null)
                .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
        } catch (err: any) {
            this.logger.error({ err: err?.message }, "Failed to fetch recent runs from KV");
            return [];
        }
    }
}
