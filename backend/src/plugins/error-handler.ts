/**
 * Sellio Metrics Backend — Central Error Handler Plugin
 *
 * Catches all errors thrown in route handlers and returns
 * a consistent JSON error response. Logs unexpected errors.
 */

import { FastifyPluginAsync, FastifyError } from "fastify";
import fp from "fastify-plugin";
import { AppError } from "../core/errors";

const errorHandlerPlugin: FastifyPluginAsync = async (fastify) => {
    fastify.setErrorHandler((error: FastifyError | AppError, request, reply) => {
        // ── Operational errors (thrown intentionally) ──
        if (error instanceof AppError) {
            request.log.warn(
                { code: error.code, statusCode: error.statusCode },
                error.message,
            );
            return reply.status(error.statusCode).send({
                error: error.code,
                message: error.message,
                statusCode: error.statusCode,
            });
        }

        // ── Fastify validation errors ──
        const fastifyErr = error as FastifyError;
        if (fastifyErr.validation) {
            return reply.status(400).send({
                error: "VALIDATION_ERROR",
                message: fastifyErr.message,
                statusCode: 400,
            });
        }

        // ── Unexpected errors (bugs) ──
        request.log.error(error, "Unexpected error");
        return reply.status(500).send({
            error: "INTERNAL_ERROR",
            message: "An unexpected error occurred",
            statusCode: 500,
        });
    });
};

export default fp(errorHandlerPlugin, { name: "error-handler" });
