/**
 * Sellio Metrics Backend — App Factory
 *
 * Creates and configures the Fastify application.
 * Registers plugins, DI scope, and module routes.
 *
 * This is separate from server.ts so the app can be tested
 * without actually starting the server.
 */

import Fastify, { FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import { diContainer, fastifyAwilixPlugin } from "@fastify/awilix";
import type { AwilixContainer } from "awilix";

import type { Cradle } from "./core/container";
import errorHandlerPlugin from "./plugins/error-handler";
import rateLimitPlugin from "./plugins/rate-limit";

// Module routes
import healthRoute from "./modules/health/health.route";
import reposRoute from "./modules/repos/repos.route";
import metricsRoute from "./modules/metrics/metrics.route";

export interface BuildAppOptions {
    container: AwilixContainer<Cradle>;
    logLevel?: string;
}

export async function buildApp(options: BuildAppOptions): Promise<FastifyInstance> {
    const { container, logLevel = "info" } = options;

    const app = Fastify({
        logger: {
            level: logLevel,
            transport:
                process.env.NODE_ENV !== "production"
                    ? { target: "pino-pretty", options: { colorize: true } }
                    : undefined,
        },
    });

    // ─── Cross-cutting plugins ──────────────────────────────
    await app.register(cors, { origin: "*", methods: ["GET"] });
    await app.register(errorHandlerPlugin);
    await app.register(rateLimitPlugin);

    // ─── DI: expose container to all routes ─────────────────
    await app.register(fastifyAwilixPlugin, {
        disposeOnClose: true,
        disposeOnResponse: true,
    });

    // Copy registrations from our built container into Fastify's DI
    diContainer.register(container.registrations);

    // ─── Routes ─────────────────────────────────────────────
    await app.register(healthRoute, { prefix: "/api/health" });
    await app.register(reposRoute, { prefix: "/api/repos" });
    await app.register(metricsRoute, { prefix: "/api/metrics" });

    return app;
}
