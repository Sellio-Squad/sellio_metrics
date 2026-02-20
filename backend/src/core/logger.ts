/**
 * Sellio Metrics Backend — Logger
 *
 * Creates a pre-configured Pino logger instance.
 * Fastify uses Pino internally; this ensures consistent config.
 */

import pino from "pino";
import { env } from "../config/env";

export const logger = pino({
    level: env.logLevel,
    transport:
        process.env.NODE_ENV !== "production"
            ? { target: "pino-pretty", options: { colorize: true } }
            : undefined,
});

export type Logger = pino.Logger;
