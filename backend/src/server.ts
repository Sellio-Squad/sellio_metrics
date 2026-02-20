/**
 * Sellio Metrics Backend — Server Entry Point
 *
 * Bootstraps the application:
 * 1. Validates config (fail fast)
 * 2. Builds DI container
 * 3. Creates Fastify app
 * 4. Starts listening
 */

import { env } from "./config/env";
import { buildContainer } from "./core/container";
import { logger } from "./core/logger";
import { buildApp } from "./app";

async function main() {
    try {
        // Step 1: Config already validated on import via env.ts

        // Step 2: Build DI container
        const container = buildContainer();

        // ── Private key format diagnostics (helps debug OpenSSL errors) ──
        const keyLines = env.privateKey.split("\n");
        logger.info(
            {
                keyFirstLine: keyLines[0],
                keyLastLine: keyLines[keyLines.length - 1],
                keyLineCount: keyLines.length,
                keyHasNewlines: env.privateKey.includes("\n"),
            },
            "🔑 Private key format check",
        );

        logger.info("DI container built");

        // Step 3: Create the Fastify app
        const app = await buildApp({
            container,
            logLevel: env.logLevel,
        });

        // Step 4: Start listening
        await app.listen({ port: env.port, host: "0.0.0.0" });

        logger.info(
            {
                port: env.port,
                org: env.org,
                endpoints: [
                    "GET /api/health",
                    "GET /api/repos",
                    "GET /api/metrics/:owner/:repo",
                ],
            },
            `🚀 Sellio Metrics Backend running on http://localhost:${env.port}`,
        );
    } catch (error) {
        logger.fatal(error, "Failed to start server");
        process.exit(1);
    }
}

main();
