/**
 * Observability Module — Route (Controller)
 *
 * HTTP boundary only: validates query params, calls service, shapes response.
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import type { CallsQueryParams, CallsResponse, ObservabilityStats } from "./observability.types";

const observabilityRoute: FastifyPluginAsync = async (fastify) => {
    /**
     * GET /api/observability/stats
     */
    fastify.get(
        "/stats",
        async (request, reply) => {
            try {
                const { observabilityService, cacheService } = request.diScope.cradle as Cradle;
                const stats = observabilityService.getStats();
                const cacheStats = await cacheService.getStats();
                return { ...stats, cacheStats };
            } catch (err) {
                request.log.error({ err }, "Failed to compute observability stats");
                reply.code(500);
                return { error: "Failed to compute stats", message: String(err) };
            }
        },
    );

    /**
     * GET /api/observability/calls?source=github&limit=50&offset=0
     */
    fastify.get<{ Querystring: CallsQueryParams; Reply: CallsResponse }>(
        "/calls",
        {
            schema: {
                querystring: {
                    type: "object",
                    properties: {
                        source: { type: "string", enum: ["internal", "github", "google", "external", "cache"] },
                        limit: { type: "integer", minimum: 1, maximum: 500, default: 100 },
                        offset: { type: "integer", minimum: 0, default: 0 },
                    },
                },
            },
        },
        async (request) => {
            const { observabilityService } = request.diScope.cradle as Cradle;
            const { source, limit = 100, offset = 0 } = request.query;
            const result = observabilityService.getRecentCalls(limit, offset, source);
            return { total: result.total, count: result.calls.length, calls: result.calls };
        },
    );

    /**
     * DELETE /api/observability/calls — clears the buffer (dev only)
     */
    fastify.delete("/calls", async (request) => {
        const { observabilityService } = request.diScope.cradle as Cradle;
        observabilityService.clear();
        return { status: "cleared" };
    });
};

export default observabilityRoute;
