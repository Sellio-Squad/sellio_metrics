/**
 * Sellio Metrics Backend — Cloudflare Worker Entry Point
 *
 * Bridges Cloudflare Workers' fetch() API → Fastify's inject() method.
 * The Fastify app is built once and reused across requests.
 *
 * How it works:
 *   1. First request: copy Worker env bindings → process.env
 *   2. Build DI container + Fastify app (lazy, singleton)
 *   3. Convert incoming Request → app.inject() → Response
 */

import type { FastifyInstance } from "fastify";

// ─── Worker Env Bindings ────────────────────────────────────

interface WorkerEnv {
    // Secrets (set via dashboard / wrangler secret put)
    APP_ID: string;
    INSTALLATION_ID: string;
    APP_PRIVATE_KEY: string;

    // Vars (set in wrangler.toml [vars])
    GITHUB_ORG?: string;
    LOG_LEVEL?: string;
    NODE_ENV?: string;
}

// ─── Lazy App Singleton ─────────────────────────────────────

let appPromise: Promise<FastifyInstance> | null = null;

function getApp(): Promise<FastifyInstance> {
    if (!appPromise) {
        appPromise = (async () => {
            // Dynamic imports so env.ts reads process.env AFTER we populate it
            const { buildContainer } = await import("./core/container");
            const { buildApp } = await import("./app");

            const container = buildContainer();
            const app = await buildApp({
                container,
                logLevel: process.env.LOG_LEVEL || "info",
            });

            return app;
        })();
    }
    return appPromise;
}

// ─── Fetch Handler ──────────────────────────────────────────

export default {
    async fetch(request: Request, workerEnv: WorkerEnv): Promise<Response> {
        // Step 1: Populate process.env from Worker bindings (once)
        if (!process.env.APP_ID) {
            process.env.APP_ID = workerEnv.APP_ID;
            process.env.INSTALLATION_ID = workerEnv.INSTALLATION_ID;
            process.env.APP_PRIVATE_KEY = workerEnv.APP_PRIVATE_KEY;
            if (workerEnv.GITHUB_ORG) process.env.GITHUB_ORG = workerEnv.GITHUB_ORG;
            if (workerEnv.LOG_LEVEL) process.env.LOG_LEVEL = workerEnv.LOG_LEVEL;
            // NODE_ENV is set via wrangler.toml [vars] — esbuild defines it at build time

        }

        // Step 2: Get or create the Fastify app
        const app = await getApp();

        // Step 3: Convert Request → Fastify inject()
        const url = new URL(request.url);

        const headers: Record<string, string> = {};
        request.headers.forEach((value, key) => {
            headers[key] = value;
        });

        const body =
            request.method !== "GET" && request.method !== "HEAD"
                ? await request.text()
                : undefined;

        const response = await app.inject({
            method: request.method as any,
            url: url.pathname + url.search,
            headers,
            payload: body,
        });

        // Step 4: Convert Fastify response → Worker Response
        const responseHeaders = new Headers();
        for (const [key, value] of Object.entries(response.headers)) {
            if (value === undefined) continue;
            if (Array.isArray(value)) {
                for (const v of value) {
                    responseHeaders.append(key, v);
                }
            } else {
                responseHeaders.set(key, String(value));
            }
        }

        return new Response(response.body, {
            status: response.statusCode,
            headers: responseHeaders,
        });
    },
};
