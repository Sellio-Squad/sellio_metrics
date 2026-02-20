/**
 * Sellio Metrics Backend — Rate Limiter Plugin
 *
 * Protects the API from excessive requests.
 * Uses @fastify/rate-limit with config from env.
 */

import { FastifyPluginAsync } from "fastify";
import fp from "fastify-plugin";
import rateLimit from "@fastify/rate-limit";
import { env } from "../config/env";

const rateLimitPlugin: FastifyPluginAsync = async (fastify) => {
    await fastify.register(rateLimit, {
        max: env.rateLimitMax,
        timeWindow: env.rateLimitWindowMs,
        errorResponseBuilder: () => ({
            error: "RATE_LIMIT",
            message: "Too many requests. Please slow down.",
            statusCode: 429,
        }),
    });
};

export default fp(rateLimitPlugin, { name: "rate-limit" });
