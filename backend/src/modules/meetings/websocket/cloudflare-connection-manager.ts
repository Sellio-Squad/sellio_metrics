/**
 * Cloudflare Durable Object — WebSocket Connection Manager
 *
 * Implements IConnectionManager using Cloudflare's WebSocket Hibernation API.
 * Features:
 *   - Auto ping/pong via setWebSocketAutoResponse (DO stays asleep)
 *   - Connection limit enforcement
 *   - Debug-level logging on broadcast failures
 */

import type { DurableObjectState } from "@cloudflare/workers-types";
import type { IConnectionManager, BroadcastResult } from "./connection-manager";
import type { Logger } from "../../../core/logger";

/** Default max concurrent WebSocket connections per meeting room */
const DEFAULT_MAX_CONNECTIONS = 100;

export class CloudflareConnectionManager implements IConnectionManager {
    private readonly state:  DurableObjectState;
    private readonly logger: Logger;
    private readonly maxConnections: number;

    constructor(state: DurableObjectState, logger: Logger, maxConnections = DEFAULT_MAX_CONNECTIONS) {
        this.state          = state;
        this.logger         = logger;
        this.maxConnections = maxConnections;

        // Auto ping/pong — the DO does NOT need to wake up for heartbeats.
        // Cloudflare handles it at the platform level, keeping connections alive.
        try {
            (this.state as any).setWebSocketAutoResponse(
                new (globalThis as any).WebSocketRequestResponsePair(
                    JSON.stringify({ type: "ping" }),
                    JSON.stringify({ type: "pong" }),
                ),
            );
        } catch {
            // setWebSocketAutoResponse may not be available in older compat dates
            this.logger.warn("setWebSocketAutoResponse not available — falling back to manual ping/pong");
        }
    }

    // ─── Accept Upgrade ─────────────────────────────────────────────────────

    acceptUpgrade(request: Request): Response {
        // Enforce connection limit
        const currentCount = this.getConnectionCount();
        if (currentCount >= this.maxConnections) {
            this.logger.warn({ currentCount, maxConnections: this.maxConnections }, "Connection limit reached — rejecting upgrade");
            return new Response("Too Many Connections", { status: 429 });
        }

        // Validate upgrade header
        if (request.headers.get("Upgrade") !== "websocket") {
            return new Response("Expected WebSocket upgrade", { status: 426 });
        }

        // Create WebSocket pair
        const pair = new (globalThis as any).WebSocketPair() as { 0: WebSocket; 1: WebSocket };
        const [client, server] = [pair[0], pair[1]];

        // Hibernation API — DO can unload from memory between messages
        (this.state as any).acceptWebSocket(server);

        this.logger.info({ connectionCount: currentCount + 1 }, "WebSocket client connected");

        return new Response(null, { status: 101, webSocket: client } as any);
    }

    // ─── Broadcast ──────────────────────────────────────────────────────────

    broadcast(payload: string): BroadcastResult {
        const connections = (this.state as any).getWebSockets() as WebSocket[];
        let sent   = 0;
        let failed = 0;

        for (const ws of connections) {
            try {
                ws.send(payload);
                sent++;
            } catch (err: any) {
                this.logger.debug({ err: err?.message }, "Broadcast failed for stale connection");
                failed++;
            }
        }

        return { sent, failed };
    }

    // ─── Connection Count ───────────────────────────────────────────────────

    getConnectionCount(): number {
        return ((this.state as any).getWebSockets() as WebSocket[]).length;
    }

    // ─── Close All ──────────────────────────────────────────────────────────

    closeAll(code: number, reason: string): void {
        const connections = (this.state as any).getWebSockets() as WebSocket[];
        for (const ws of connections) {
            try {
                ws.close(code, reason);
            } catch (err: any) {
                this.logger.debug({ err: err?.message }, "Error closing WebSocket connection");
            }
        }
    }
}
