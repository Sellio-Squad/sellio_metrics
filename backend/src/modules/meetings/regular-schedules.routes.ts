import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import type { RegularSchedulesRepository } from "./regular-schedules.repository";
import type { CreateRegularMeetingScheduleBody } from "./regular-schedules.types";

/**
 * Regular Meeting Schedules — HTTP Routes
 *
 * GET    /api/meetings/schedules        → list all schedules
 * POST   /api/meetings/schedules        → create a schedule
 * DELETE /api/meetings/schedules/:id    → delete a schedule
 */
export function regularSchedulesRoutes(repo: RegularSchedulesRepository) {
    const app = new Hono<HonoEnv>();

    // ── List all schedules ───────────────────────────────────────────────────
    app.get("/", async (c) => {
        const schedules = await repo.findAll();
        return c.json(schedules);
    });

    // ── Create a schedule ────────────────────────────────────────────────────
    app.post("/", async (c) => {
        let body: CreateRegularMeetingScheduleBody;
        try {
            body = await c.req.json<CreateRegularMeetingScheduleBody>();
        } catch {
            return c.json({ error: "Invalid JSON body" }, 400);
        }

        if (!body.title?.trim())           return c.json({ error: "title is required" }, 400);
        if (!body.dayTime?.trim())         return c.json({ error: "dayTime is required" }, 400);
        if (!body.recurrenceRule?.trim())   return c.json({ error: "recurrenceRule is required" }, 400);
        if (typeof body.iconCode !== "number")    return c.json({ error: "iconCode must be a number" }, 400);
        if (typeof body.accentColor !== "number") return c.json({ error: "accentColor must be a number" }, 400);
        if (typeof body.durationMinutes !== "number") return c.json({ error: "durationMinutes must be a number" }, 400);

        const created = await repo.insert(body);
        return c.json(created, 201);
    });

    // ── Delete a schedule ────────────────────────────────────────────────────
    app.delete("/:id", async (c) => {
        const id = c.req.param("id");
        await repo.delete(id);
        return c.json({ success: true });
    });

    return app;
}
