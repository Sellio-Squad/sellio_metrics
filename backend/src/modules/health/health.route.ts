/**
 * Health Module — Route
 *
 * Simple health check endpoint.
 */

import { FastifyPluginAsync } from "fastify";
import type { Cradle } from "../../core/container";
import { env } from "../../config/env";

const healthRoute: FastifyPluginAsync = async (fastify) => {
    fastify.get("/", async (request) => {
        const { rateLimitGuard } = request.diScope.cradle as Cradle;

        return {
            status: "ok",
            org: env.org,
            timestamp: new Date().toISOString(),
            githubRateLimit: rateLimitGuard.getStatus(),
        };
    });
};

export default healthRoute;
