import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import type { CFDurableObjectNamespace } from "../meetings/meetings.routes";
import type { AiRunRecord } from "./ai-pipeline.types";

export function aiPipelineRoutes(aiPipelineHub: CFDurableObjectNamespace) {
    const app = new Hono<HonoEnv>();

    // WebSocket upgrade route
    app.get("/ws", (c) => {
        const doId = aiPipelineHub.idFromName("global");
        const doStub = aiPipelineHub.get(doId);
        return doStub.fetch(c.req.raw);
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

    return app;
}
