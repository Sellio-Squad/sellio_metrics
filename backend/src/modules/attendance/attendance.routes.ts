/**
 * Attendance Routes
 * POST /api/attendance/check-in
 * POST /api/attendance/check-out
 * GET  /api/attendance/history
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";
import { z } from "zod";
import { zValidator } from "@hono/zod-validator";

const checkInSchema = z.object({
    developerId: z.string(),
    checkin_time: z.string().optional(),
    meeting_id: z.string().optional(),
    location: z.string().optional(),
});
type CheckInBody = z.infer<typeof checkInSchema>;

const checkOutSchema = z.object({
    developerId: z.string(),
    checkout_time: z.string().optional(),
    meeting_id: z.string().optional(),
    location: z.string().optional(),
});
type CheckOutBody = z.infer<typeof checkOutSchema>;

const historyQuerySchema = z.object({
    developerLogin: z.string().optional(),
    developerId: z.string().optional(),
    since: z.string().optional(),
    until: z.string().optional(),
    limit: z.coerce.number().int().min(1).default(50),
});
type HistoryQuery = z.infer<typeof historyQuerySchema>;

// ─── Routes ──────────────────────────────────────────────────

const attendance = new Hono<HonoEnv>();

attendance.post("/check-in", zValidator("json", checkInSchema), safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const body = c.req.valid("json") as CheckInBody;

    const result = await attendanceService.checkIn(body.developerId, {
        checkin_time: body.checkin_time || new Date().toISOString(),
        meeting_id:   body.meeting_id,
        location:     body.location,
    });
    return c.json(result);
}));

attendance.post("/check-out", zValidator("json", checkOutSchema), safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const body = c.req.valid("json") as CheckOutBody;

    const result = await attendanceService.checkOut(body.developerId, {
        checkout_time: body.checkout_time || new Date().toISOString(),
        meeting_id:    body.meeting_id,
        location:      body.location,
    });
    return c.json(result);
}));

attendance.get("/history", zValidator("query", historyQuerySchema), safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const { developerLogin, developerId, since, until, limit } = c.req.valid("query") as HistoryQuery;
    const login = developerLogin || developerId;

    const events = await attendanceService.getHistory({ developerLogin: login, since, until, limit });
    return c.json({ count: events.length, events });
}));

export default attendance;
