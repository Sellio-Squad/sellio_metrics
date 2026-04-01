/**
 * WebSocket Connection Manager — Platform-Agnostic Interface
 *
 * Abstracts WebSocket connection lifecycle so the meeting business logic
 * is decoupled from the hosting platform.
 *
 * Implementations:
 *   - CloudflareConnectionManager  (Durable Objects + Hibernation API)
 *   - Future: WsConnectionManager  (Node.js `ws` library)
 *   - Future: SocketIOManager       (Socket.IO)
 */

// ─── Broadcast Result ───────────────────────────────────────────────────────

export interface BroadcastResult {
    /** Number of clients that received the message */
    sent: number;
    /** Number of clients where send failed (stale / closed) */
    failed: number;
}

// ─── Connection Manager Contract ────────────────────────────────────────────

export interface IConnectionManager {
    /**
     * Accept a WebSocket upgrade request.
     * Returns an HTTP response (101 on success, 4xx on rejection).
     */
    acceptUpgrade(request: Request): Response;

    /**
     * Send a JSON string to all connected clients.
     */
    broadcast(payload: string): BroadcastResult;

    /**
     * Number of currently active connections.
     */
    getConnectionCount(): number;

    /**
     * Close all connections with the specified code and reason.
     */
    closeAll(code: number, reason: string): void;
}
