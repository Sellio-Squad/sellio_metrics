/**
 * Sellio Metrics — Cloudflare Worker Entry Point
 *
 * Thin Hono app: global CORS, DI cradle injected via middleware,
 * all feature routes mounted under /api.
 *
 * Route map:
 *   GET  /api/ping | /api/health
 *   GET  /api/repos
 *   GET  /api/prs
 *   POST /api/sync/github
 *   POST /api/webhooks/github
 *   GET|PUT /api/points/rules
 *   GET  /api/scores/leaderboard
 *   GET  /api/members
 *   DELETE /api/developers/:id/events
 *   GET|POST|DELETE /api/meetings/*
 *   GET  /api/meetings/:id/ws  (WebSocket via MeetingRoom Durable Object)
 *   GET  /api/debug/* | /api/logs
 */

import { Hono } from "hono";
import { cors } from "hono/cors";
import type { HonoEnv } from "./core/hono-env";
import type { Cradle } from "./core/container";
import type { KVNamespace } from "./infra/cache/cache.service";
import type { D1Database } from "./infra/database/d1.service";
import type { ExecutionContext } from "@cloudflare/workers-types";
import { getContainer } from "./core/container-factory";

// ─── Route modules ─────────────────────────────────────────────────────
import healthRoutes     from "./modules/health/health.routes";
import reposRoutes      from "./modules/repos/repos.routes";
import prsRoutes        from "./modules/prs/prs.routes";
import syncRoutes       from "./modules/sync/sync.routes";
import webhookRoutes    from "./modules/webhook/webhook.routes";
import pointsRoutes     from "./modules/points/points.routes";
import scoresRoutes     from "./modules/scores/scores.routes";
import membersRoutes    from "./modules/members/members.routes";
import developersRoutes from "./modules/developers/developers.routes";
import { meetingsRoutes, type CFDurableObjectNamespace } from "./modules/meetings/meetings.routes";
import { regularSchedulesRoutes } from "./modules/meetings/regular-schedules.routes";
import debugRoutes      from "./modules/debug/debug.routes";
import logsRoutes       from "./modules/logs/logs.routes";
import reviewRoutes     from "./modules/review/review.routes";

// ─── Durable Object export (required by Cloudflare runtime) ────────────────
export { MeetingRoom } from "./modules/meetings/meeting-room.do";

// ─── Cloudflare Worker bindings ────────────────────────────────────────

interface WorkerEnv {
    APP_ID:              string;
    INSTALLATION_ID:     string;
    APP_PRIVATE_KEY:     string;
    GITHUB_ORG?:         string;
    LOG_LEVEL?:          string;
    GOOGLE_CLIENT_ID?:   string;
    GOOGLE_CLIENT_SECRET?: string;
    GOOGLE_REDIRECT_URI?:  string;
    GOOGLE_PUBSUB_TOPIC?:  string;
    CACHE:          KVNamespace;
    SCORES_KV:      KVNamespace;
    MEMBERS_KV:     KVNamespace;
    ATTENDANCE_KV:  KVNamespace;
    DB:             D1Database;
    WEBHOOK_QUEUE?: any;
    MEETING_ROOMS:  CFDurableObjectNamespace;
    GEMINI_API_KEY?: string;
}

// ─── Helpers ───────────────────────────────────────────────────────────

function bootstrapEnv(workerEnv: WorkerEnv): void {
    if (process.env.APP_ID) return; // Already set on warm instance
    process.env.APP_ID          = workerEnv.APP_ID;
    process.env.INSTALLATION_ID = workerEnv.INSTALLATION_ID;
    process.env.APP_PRIVATE_KEY = workerEnv.APP_PRIVATE_KEY;
    if (workerEnv.GITHUB_ORG)           process.env.GITHUB_ORG           = workerEnv.GITHUB_ORG;
    if (workerEnv.LOG_LEVEL)             process.env.LOG_LEVEL            = workerEnv.LOG_LEVEL;
    if (workerEnv.GOOGLE_CLIENT_ID)      process.env.GOOGLE_CLIENT_ID     = workerEnv.GOOGLE_CLIENT_ID;
    if (workerEnv.GOOGLE_CLIENT_SECRET)  process.env.GOOGLE_CLIENT_SECRET = workerEnv.GOOGLE_CLIENT_SECRET;
    if (workerEnv.GOOGLE_REDIRECT_URI)   process.env.GOOGLE_REDIRECT_URI  = workerEnv.GOOGLE_REDIRECT_URI;
    if (workerEnv.GOOGLE_PUBSUB_TOPIC)   process.env.GOOGLE_PUBSUB_TOPIC  = workerEnv.GOOGLE_PUBSUB_TOPIC;
    if (workerEnv.GEMINI_API_KEY)        process.env.GEMINI_API_KEY       = workerEnv.GEMINI_API_KEY;
}

function buildApp(cradle: Cradle, meetingRooms: CFDurableObjectNamespace) {
    const app = new Hono<HonoEnv>();

    // 1. CORS — must be first
    app.use("*", cors({
        origin:       "*",
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"],
    }));

    // 2. Cradle injection — must come BEFORE routes so c.get('cradle') is available
    app.use("*", async (c, next) => {
        c.set("cradle", cradle);
        const start = Date.now();
        await next();
        const ms = Date.now() - start;
        cradle.logger.info({
            module: "system",
            category: "system",
            method: c.req.method,
            path: new URL(c.req.url).pathname,
            status: c.res.status,
            duration: ms
        }, `${c.req.method} ${new URL(c.req.url).pathname} - ${c.res.status} (${ms}ms)`);
    });

    // 3. Route modules
    app.route("/api",             healthRoutes);
    app.route("/api/repos",       reposRoutes);
    app.route("/api/prs",         prsRoutes);
    app.route("/api/sync",        syncRoutes);
    app.route("/api/webhooks",    webhookRoutes);
    app.route("/api/points",      pointsRoutes);
    app.route("/api/scores",      scoresRoutes);
    app.route("/api/members",     membersRoutes);
    app.route("/api/developers",  developersRoutes);
    app.route("/api/meetings",    meetingsRoutes(
        cradle.meetingsService,
        cradle.webhookHandlerService,
        meetingRooms,
    ));
    app.route("/api/meetings/schedules", regularSchedulesRoutes(cradle.regularSchedulesRepo));
    app.route("/api/debug",       debugRoutes);
    app.route("/api/logs",        logsRoutes);
    app.route("/api/review",      reviewRoutes);

    app.notFound((c) => c.json({ error: "Not Found" }, 404));

    return app;
}

// ─── Worker export ─────────────────────────────────────────────────────

export default {
    async fetch(request: Request, workerEnv: WorkerEnv, ctx: ExecutionContext): Promise<Response> {
        try {
            bootstrapEnv(workerEnv);

            const container = await getContainer(
                workerEnv.CACHE        || null,
                workerEnv.SCORES_KV    || null,
                workerEnv.MEMBERS_KV   || null,
                workerEnv.ATTENDANCE_KV || null,
                workerEnv.DB           || null,
                workerEnv.WEBHOOK_QUEUE || null,
            );

            const app = buildApp(container.cradle, workerEnv.MEETING_ROOMS);

            return app.fetch(request, workerEnv as any, ctx);
        } catch (e: any) {
            console.error("Worker fetch error:", e?.message, e?.stack);
            return new Response(
                JSON.stringify({ error: e?.message || "Internal Server Error" }),
                { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } },
            );
        }
    },

    // ─── Cron (e.g. every 6h — refresh leaderboard snapshots) ──
    async scheduled(_event: ScheduledEvent, workerEnv: WorkerEnv): Promise<void> {
        try {
            bootstrapEnv(workerEnv);
            const container = await getContainer(
                workerEnv.CACHE        || null,
                workerEnv.SCORES_KV    || null,
                workerEnv.MEMBERS_KV   || null,
                workerEnv.ATTENDANCE_KV || null,
                workerEnv.DB           || null,
                workerEnv.WEBHOOK_QUEUE || null,
            );
            await container.cradle.scoreAggregationService.precomputeSnapshots();
            console.log("Cron: leaderboard snapshots refreshed");
        } catch (e: any) {
            console.error("Cron error:", e?.message, e?.stack);
        }
    },

    // ─── Queue consumer (webhook background tasks) ─────────
    async queue(batch: MessageBatch, workerEnv: WorkerEnv): Promise<void> {
        try {
            bootstrapEnv(workerEnv);
            const container = await getContainer(
                workerEnv.CACHE        || null,
                workerEnv.SCORES_KV    || null,
                workerEnv.MEMBERS_KV   || null,
                workerEnv.ATTENDANCE_KV || null,
                workerEnv.DB           || null,
                workerEnv.WEBHOOK_QUEUE || null,
            );

            for (const msg of batch.messages) {
                try {
                    const body = msg.body as { type: string; developers?: string[] };
                    if (body.type === "recompute_scores") {
                        await container.cradle.scoreAggregationService
                            .precomputeSnapshots(body.developers);
                    }
                    msg.ack();
                } catch (e: any) {
                    console.error("Queue message processing error:", e?.message);
                    msg.retry();
                }
            }
        } catch (e: any) {
            console.error("Queue handler error:", e?.message, e?.stack);
        }
    },
};

// ─── Cloudflare runtime types ───────────────────────────────────────────
interface ScheduledEvent { scheduledTime: number; cron: string; }
interface MessageBatch { messages: QueueMessage[]; }
interface QueueMessage { body: unknown; ack(): void; retry(): void; }
