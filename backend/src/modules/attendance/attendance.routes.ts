/**
 * Attendance Routes
 * POST /api/attendance/check-in
 * POST /api/attendance/check-out
 * GET  /api/attendance/history
 */

import { Hono } from "hono";
import type { HonoEnv } from "../../core/hono-env";
import { useCradle, safe } from "../../lib/route-helpers";

// ─── Request body types ───────────────────────────────────────

interface CheckInBody {
    developerId: string;
    checkin_time?: string;
    meeting_id?: string;
    location?: string;
}

interface CheckOutBody {
    developerId: string;
    checkout_time?: string;
    meeting_id?: string;
    location?: string;
}

// ─── Routes ──────────────────────────────────────────────────

const attendance = new Hono<HonoEnv>();

attendance.post("/check-in", safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const body = await c.req.json<CheckInBody>();

    if (!body.developerId) return c.json({ error: "Body must contain 'developerId'" }, 400);

    const result = await attendanceService.checkIn(body.developerId, {
        checkin_time: body.checkin_time || new Date().toISOString(),
        meeting_id:   body.meeting_id,
        location:     body.location,
    });
    return c.json(result);
}));

attendance.post("/check-out", safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const body = await c.req.json<CheckOutBody>();

    if (!body.developerId) return c.json({ error: "Body must contain 'developerId'" }, 400);

    const result = await attendanceService.checkOut(body.developerId, {
        checkout_time: body.checkout_time || new Date().toISOString(),
        meeting_id:    body.meeting_id,
        location:      body.location,
    });
    return c.json(result);
}));

attendance.get("/history", safe(async (c) => {
    const { attendanceService } = useCradle(c);
    const developerLogin = c.req.query("developerLogin") || c.req.query("developerId") || undefined;
    const since       = c.req.query("since") || undefined;
    const until       = c.req.query("until") || undefined;
    const limit       = parseInt(c.req.query("limit") || "50", 10);

    const events = await attendanceService.getHistory({ developerLogin, since, until, limit });
    return c.json({ count: events.length, events });
}));

export default attendance;
