/**
 * Request Tracker Plugin — Cross-cutting Observability Hook
 *
 * Fastify plugin that automatically instruments ALL incoming HTTP requests.
 * Uses onRequest/onResponse hooks to capture timing and status.
 *
 * Separation of concerns:
 * - This plugin ONLY captures internal server requests.
 * - External API tracking (GitHub, Google) is handled by dedicated wrappers.
 * - The plugin knows nothing about how data is stored — it calls ObservabilityService.
 *
 * Self-exclusion: Requests to /api/observability/* are NOT tracked to avoid recursion.
 */

import { FastifyPluginAsync } from "fastify";
import fp from "fastify-plugin";
import type { Cradle } from "../core/container";

// Extend Fastify request to carry the start timestamp
declare module "fastify" {
    interface FastifyRequest {
        /** High-resolution start time set by the request-tracker plugin. */
        _trackStartTime?: [number, number];
    }
}

const requestTrackerPlugin: FastifyPluginAsync = async (fastify) => {
    // ─── onRequest: stamp start time ────────────────────────
    fastify.addHook("onRequest", async (request) => {
        request._trackStartTime = process.hrtime();
    });

    // ─── onResponse: compute duration and record ────────────
    fastify.addHook("onResponse", async (request, reply) => {
        // Skip observability endpoints to prevent recursive tracking
        if (request.url.startsWith("/api/observability")) {
            return;
        }

        if (!request._trackStartTime) return;

        const [seconds, nanoseconds] = process.hrtime(request._trackStartTime);
        const durationMs = seconds * 1000 + nanoseconds / 1_000_000;

        try {
            const { observabilityService } = request.diScope.cradle as Cradle;

            observabilityService.record({
                source: "internal",
                method: request.method,
                path: request.url,
                statusCode: reply.statusCode,
                durationMs,
                ...(reply.statusCode >= 400 && {
                    error: `HTTP ${reply.statusCode}`,
                }),
            });
        } catch {
            // Silently ignore — observability must never break the app
        }
    });
};

export default fp(requestTrackerPlugin, { name: "request-tracker" });
