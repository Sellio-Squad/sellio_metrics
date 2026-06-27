import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import type { CFDurableObjectNamespace } from "../meetings/meetings.routes";
import type { AiRunRecord } from "./ai-pipeline.types";

const WEBHOOK_SECRET = process.env.SELLIO_WEBHOOK_SECRET ?? "";

export function aiPipelineRoutes(aiPipelineHub: CFDurableObjectNamespace) {
    const app = new Hono<HonoEnv>();

    // WebSocket upgrade route
    app.get("/ws", (c) => {
        const doId = aiPipelineHub.idFromName("global");
        const doStub = aiPipelineHub.get(doId);
        return doStub.fetch(c.req.raw);
    });

    // ─── GitHub Actions agent callback ───────────────────────
    // Called by .github/workflows/ai-implement.yml when the agent finishes.
    // Header: X-Sellio-Signature must match SELLIO_WEBHOOK_SECRET.
    app.post("/result", async (c) => {
        const { aiPipelineService, logger } = c.get("cradle");

        // Verify shared secret
        const sig = c.req.header("X-Sellio-Signature");
        if (!sig || sig !== WEBHOOK_SECRET) {
            logger.warn({ sig }, "ai-pipeline /result: invalid signature");
            return c.json({ error: "Unauthorized" }, 401);
        }

        let body: {
            taskId: string;
            branch: string;
            status: "success" | "failed";
            owner: string;
            repo: string;
            issueNumber: number;
            error?: string;
        };

        try {
            body = await c.req.json();
        } catch {
            return c.json({ error: "Invalid JSON body" }, 400);
        }

        if (!body.taskId || !body.status) {
            return c.json({ error: "Missing taskId or status" }, 400);
        }

        try {
            await aiPipelineService.receiveAgentResult(body);
            return c.json({ ok: true });
        } catch (err: any) {
            logger.error({ taskId: body.taskId, err: err.message }, "Failed to process agent result");
            return c.json({ error: err.message }, 500);
        }
    });

    // REST list for debugging or fallback
    app.get("/runs", async (c) => {
        const { cacheService, logger } = c.get("cradle");
        try {
            const indexVal = await cacheService.get<string[]>("ai:runs:index");
            if (!indexVal || !indexVal.data) {
                return c.json([]);
            }
            const taskIds = indexVal.data;
            if (!Array.isArray(taskIds) || taskIds.length === 0) {
                return c.json([]);
            }

            const records = await Promise.all(
                taskIds.map(async (taskId) => {
                    const recordVal = await cacheService.get<AiRunRecord>(`ai:runs:${taskId}`);
                    return recordVal ? recordVal.data : null;
                })
            );

            const sorted = records
                .filter((r): r is AiRunRecord => r !== null)
                .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());

            return c.json(sorted);
        } catch (err: any) {
            logger.error({ err: err?.message }, "Failed to fetch runs list");
            return c.json({ error: "Failed to fetch runs list" }, 500);
        }
    });

    app.delete("/runs", async (c) => {
        const { aiPipelineService, logger } = c.get("cradle");
        try {
            await aiPipelineService.deleteAllRuns();
            
            const doId = aiPipelineHub.idFromName("global");
            const doStub = aiPipelineHub.get(doId);
            await doStub.fetch(new Request("http://do/event/clear", { method: "POST" }));

            return c.json({ success: true });
        } catch (err: any) {
            logger.error({ err: err?.message }, "Failed to clear runs history");
            return c.json({ error: "Failed to clear runs history" }, 500);
        }
    });

    app.delete("/runs/:taskId", async (c) => {
        const taskId = c.req.param("taskId");
        const { aiPipelineService, logger } = c.get("cradle");
        try {
            await aiPipelineService.deleteRun(taskId);
            
            const doId = aiPipelineHub.idFromName("global");
            const doStub = aiPipelineHub.get(doId);
            await doStub.fetch(new Request(`http://do/event/delete/${taskId}`, { method: "POST" }));

            return c.json({ success: true });
        } catch (err: any) {
            logger.error({ taskId, err: err?.message }, "Failed to delete run");
            return c.json({ error: "Failed to delete run" }, 500);
        }
    });

    return app;
}
