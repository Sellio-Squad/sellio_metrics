/**
 * Health Module — Route
 *
 * Simple health check endpoint.
 */

import { FastifyPluginAsync } from "fastify";
import { env } from "../../config/env";

const healthRoute: FastifyPluginAsync = async (fastify) => {
    fastify.get("/", async () => ({
        status: "ok",
        org: env.org,
        timestamp: new Date().toISOString(),
    }));
};

export default healthRoute;
